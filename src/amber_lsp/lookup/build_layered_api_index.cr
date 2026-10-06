require "digest/sha256"
require "file_utils"
require "process"
require "random/secure"
require "yaml"

require "./build_crystal_docs_json"
require "./api_cards"
require "./index_cache"
require "./merge_api_index_layers"
require "./normalize_crystal_docs"
require "./resolve_api_index_docs_entries"
require "./source_models"

module AmberLSP::Lookup
  struct CrystalAlphaIdentity
    getter executable_path : String
    getter version : String
    getter llvm_version : String

    def initialize(@executable_path : String, @version : String, @llvm_version : String)
    end
  end

  class DetectCrystalAlpha
    def initialize(@compiler_command : String = "crystal-alpha")
    end

    def perform : CrystalAlphaIdentity
      compiler_path = Process.find_executable(@compiler_command)
      raise APIIndexBuildError.new("crystal-alpha is not available on PATH") unless compiler_path

      output = run_compiler_command(compiler_path, ["--version"])
      version = output.strip
      llvm_version = version.lines.find(&.starts_with?("LLVM:"))
        .try(&.split(':', 2).last?.try(&.strip)) || "unknown"

      CrystalAlphaIdentity.new(compiler_path, version, llvm_version)
    end

    private def run_compiler_command(compiler_path : String, arguments : Array(String)) : String
      output = IO::Memory.new
      error_output = IO::Memory.new
      status = Process.run(compiler_path, arguments, output: output, error: error_output)
      unless status.success?
        raise APIIndexBuildError.new("Could not inspect crystal-alpha: #{error_output.to_s.strip}")
      end
      output.to_s
    rescue ex : IO::Error
      raise APIIndexBuildError.new("Could not inspect crystal-alpha: #{ex.message}")
    end
  end

  # :nodoc:
  struct CrystalDocsWorkspace
    getter root_path : String
    getter list_of_entrypoints : Array(String)
    getter crystal_cache_path : String
    getter source_path_mappings : Hash(String, String)

    def initialize(
      @root_path : String,
      @list_of_entrypoints : Array(String),
      @crystal_cache_path : String,
      @source_path_mappings : Hash(String, String),
    )
    end
  end

  class BuildLayeredAPIIndex
    def initialize(
      @root_path : String,
      @cache_root : String = APIIndexCache.default_root,
      @list_of_docs_flags_by_library : Hash(String, Array(String)) = {} of String => Array(String),
      @compiler_command : String = "crystal-alpha",
    )
      @root_path = File.expand_path(@root_path)
    end

    def perform : Array(CachedAPIIndexLayer)
      manifest = read_project_manifest
      cards = LoadAPICards.new(@root_path).perform
      card_flags = cards.docs_flags_by_library
      card_entries = cards.docs_entries_by_library
      list_of_docs_flags = card_flags.merge(@list_of_docs_flags_by_library)
      identity = DetectCrystalAlpha.new(@compiler_command).perform
      cache = APIIndexCache.new(@cache_root, @root_path)
      list_of_layers = [] of CachedAPIIndexLayer
      project_name = manifest.name.empty? ? File.basename(@root_path) : manifest.name
      project_flags = docs_flags_for(project_name, list_of_docs_flags)
      project_entrypoints = project_docs_entrypoints(manifest, project_name, card_entries)
      project_key = CalculateProjectLayerKey.new(
        @root_path,
        project_flags,
        identity.version,
        project_entrypoints,
      ).perform

      list_of_layers << build_or_load_layer(
        cache,
        identity,
        "project",
        project_name,
        project_key,
        @root_path,
        project_flags,
        project_entrypoints,
        @root_path,
        {} of String => String,
      )

      locked_shards = read_locked_shards

      manifest.dependencies.keys.sort.each do |library_name|
        next if locked_shards.has_key?(library_name)

        list_of_layers << CachedAPIIndexLayer.new(
          nil,
          "unavailable",
          "#{library_name} is declared in shard.yml but is missing from shard.lock",
          "library",
          library_name,
        )
      end

      locked_shards.to_a.sort_by(&.first).each do |library_name, locked_shard|
        library_root = File.join(@root_path, "lib", library_name)
        unless File.directory?(library_root)
          list_of_layers << CachedAPIIndexLayer.new(
            nil,
            "unavailable",
            "Locked shard #{library_name} is not installed under lib/",
            "library",
            library_name,
            locked_shard.version,
          )
          next
        end

        docs_entries : Array(String)? = nil
        begin
          docs_entries = ResolveAPIIndexDocsEntries.new(
            library_root,
            library_name,
            card_entries[library_name]?,
          ).perform
        rescue ex : APIIndexBuildError
          list_of_layers << CachedAPIIndexLayer.new(
            nil,
            "unavailable",
            "Locked shard #{library_name} has no usable Crystal docs entries: #{ex.message}",
            "library",
            library_name,
            locked_shard.version,
          )
          next
        end
        resolved_docs_entries = docs_entries || raise APIIndexBuildError.new("Could not resolve docs entries for #{library_name}")

        docs_flags = docs_flags_for(library_name, list_of_docs_flags)
        layer_key = CalculateLibraryLayerKey.new(
          library_name,
          locked_shard.version,
          docs_flags,
          identity.version,
          resolved_docs_entries,
        ).perform
        list_of_layers << build_or_load_layer(
          cache,
          identity,
          "library",
          library_name,
          layer_key,
          library_root,
          docs_flags,
          resolved_docs_entries,
          library_root,
          {} of String => String,
        )
      end

      list_of_layers << standard_library_layer(cache, identity)

      list_of_layers
    end

    private def read_project_manifest : ProjectShardManifest
      shard_path = File.join(@root_path, "shard.yml")
      return ProjectShardManifest.new if !File.file?(shard_path)

      ProjectShardManifest.from_yaml(File.read(shard_path))
    rescue ex : YAML::ParseException | IO::Error
      raise APIIndexBuildError.new("Could not read shard.yml: #{ex.message}")
    end

    private def read_locked_shards : Hash(String, LockedShard)
      lock_path = File.join(@root_path, "shard.lock")
      return {} of String => LockedShard unless File.file?(lock_path)

      ShardLockfile.from_yaml(File.read(lock_path)).shards
    rescue ex : YAML::ParseException | IO::Error
      raise APIIndexBuildError.new("Could not read shard.lock: #{ex.message}")
    end

    private def find_project_entrypoint(manifest : ProjectShardManifest) : String
      target_entrypoints = manifest.targets.values.map(&.main).reject(&.empty?).sort
      target_entrypoints.each do |entrypoint|
        absolute_path = File.expand_path(entrypoint, @root_path)
        return entrypoint if File.file?(absolute_path)
      end

      if !manifest.name.empty?
        conventional_entrypoint = File.join("src", "#{manifest.name.gsub('-', '_')}.cr")
        return conventional_entrypoint if File.file?(File.join(@root_path, conventional_entrypoint))
      end

      preferred_entrypoints = ["config/application.cr", "src/application.cr"]
      preferred_entrypoints.each do |entrypoint|
        return entrypoint if File.file?(File.join(@root_path, entrypoint))
      end

      first_source = Dir.glob(File.join(@root_path, "src", "*.cr")).sort.first?
      raise APIIndexBuildError.new("No Crystal entrypoint found under #{@root_path}/src") unless first_source

      first_source.sub(@root_path + "/", "")
    end

    private def project_docs_entrypoints(
      manifest : ProjectShardManifest,
      project_name : String,
      docs_entries_by_library : Hash(String, Array(String)),
    ) : Array(String)
      has_target_main = manifest.targets.values.any? { |target| !target.main.empty? }
      has_source_files = !Dir.glob(File.join(@root_path, "src", "**", "*.cr")).empty?
      return [find_project_entrypoint(manifest)] if has_target_main || !has_source_files

      ResolveAPIIndexDocsEntries.new(
        @root_path,
        project_name,
        docs_entries_by_library[project_name]?,
      ).perform
    end

    private def docs_flags_for(library_name : String, list_of_docs_flags : Hash(String, Array(String))) : Array(String)
      list_of_docs_flags[library_name]?.try(&.sort) || [] of String
    end

    private def build_or_load_layer(
      cache : APIIndexCache,
      identity : CrystalAlphaIdentity,
      layer_kind : String,
      layer_name : String,
      layer_key : String,
      source_root : String,
      docs_flags : Array(String),
      list_of_entrypoints : Array(String),
      working_directory : String,
      environment_overrides : Hash(String, String),
    ) : CachedAPIIndexLayer
      cached_layer = cache.load_layer(layer_kind, layer_name, layer_key)
      return cached_layer if cached_layer.freshness == "fresh" || cached_layer.failure_reason

      workspace_root : String? = nil
      begin
        docs_working_directory = working_directory
        list_of_docs_entrypoints = list_of_entrypoints.map { |entrypoint| relative_entrypoint(entrypoint, working_directory) }
        docs_environment_overrides = environment_overrides
        source_path_mappings = {} of String => String

        if layer_kind == "library"
          workspace = create_library_docs_workspace(
            File.join(source_root, "src"),
            list_of_entrypoints,
            crystal_source_root(identity),
          )
          workspace_root = workspace.root_path
          docs_working_directory = workspace.root_path
          list_of_docs_entrypoints = workspace.list_of_entrypoints
          docs_environment_overrides = environment_overrides.merge({"CRYSTAL_CACHE_DIR" => workspace.crystal_cache_path})
          source_path_mappings = workspace.source_path_mappings
        end

        layer = build_layer_from_docs_entries(
          identity.executable_path,
          docs_working_directory,
          list_of_docs_entrypoints,
          layer_name,
          source_root,
          layer_kind,
          layer_key,
          docs_flags,
          docs_environment_overrides,
          docs_working_directory,
          source_path_mappings,
          list_of_entrypoints,
        )
        cache.write_layer(layer)
        CachedAPIIndexLayer.new(layer, "fresh")
      rescue ex : APIIndexBuildError | JSON::ParseException
        failure_reason = ex.message || "crystal-alpha docs could not build this API layer"
        cache.write_failure(layer_kind, layer_name, layer_key, failure_reason)
        if stale_layer = cached_layer.layer
          return CachedAPIIndexLayer.new(stale_layer, "stale", failure_reason, layer_kind, layer_name, layer_key)
        end

        CachedAPIIndexLayer.new(nil, "unavailable", failure_reason, layer_kind, layer_name, layer_key)
      ensure
        FileUtils.rm_rf(workspace_root) if workspace_root
      end
    end

    private def build_layer_from_docs_entries(
      compiler_path : String,
      working_directory : String,
      list_of_docs_entrypoints : Array(String),
      layer_name : String,
      source_root : String,
      layer_kind : String,
      layer_key : String,
      docs_flags : Array(String),
      environment_overrides : Hash(String, String),
      docs_working_directory : String,
      source_path_mappings : Hash(String, String),
      list_of_source_entrypoints : Array(String),
    ) : APIIndexLayer
      combined_failure_reason : String? = nil
      begin
        docs_json = BuildCrystalDocsJSON.new(
          compiler_path,
          working_directory,
          list_of_docs_entrypoints,
          layer_name,
          "0",
          docs_flags,
          environment_overrides,
        ).perform
        return normalize_docs_layer(
          docs_json,
          source_root,
          layer_kind,
          layer_name,
          layer_key,
          docs_flags,
          docs_working_directory,
          source_path_mappings,
        )
      rescue ex : APIIndexBuildError | JSON::ParseException
        # A combined docs invocation can fail because one entry is unavailable on its own.
        combined_failure_reason = ex.message
      end

      list_of_normalized_layers = [] of APIIndexLayer
      list_of_entry_failures = [] of APIIndexEntryFailure
      list_of_docs_entrypoints.each_with_index do |entrypoint, index|
        source_entrypoint = list_of_source_entrypoints[index]
        begin
          docs_json = BuildCrystalDocsJSON.new(
            compiler_path,
            working_directory,
            [entrypoint],
            layer_name,
            "0",
            docs_flags,
            environment_overrides,
          ).perform
          list_of_normalized_layers << normalize_docs_layer(
            docs_json,
            source_root,
            layer_kind,
            layer_name,
            layer_key,
            docs_flags,
            docs_working_directory,
            source_path_mappings,
          )
        rescue ex : APIIndexBuildError | JSON::ParseException
          list_of_entry_failures << APIIndexEntryFailure.new(
            source_entrypoint,
            ex.message || "crystal-alpha docs failed for #{source_entrypoint}",
          )
        end
      end

      main_entrypoint = list_of_source_entrypoints.first? || ""
      if main_failure = list_of_entry_failures.find { |failure| failure.entry_path == main_entrypoint }
        raise APIIndexBuildError.new("Main docs entry #{main_failure.entry_path} failed: #{main_failure.error}")
      end
      if list_of_normalized_layers.empty?
        reason = combined_failure_reason || "Combined and individual Crystal docs entries failed"
        raise APIIndexBuildError.new(reason)
      end

      MergeAPIIndexLayers.new(list_of_normalized_layers, list_of_entry_failures).perform
    end

    private def normalize_docs_layer(
      docs_json : String,
      source_root : String,
      layer_kind : String,
      layer_name : String,
      layer_key : String,
      docs_flags : Array(String),
      docs_working_directory : String,
      source_path_mappings : Hash(String, String),
    ) : APIIndexLayer
      NormalizeCrystalDocs.new(
        docs_json,
        source_root,
        layer_kind,
        layer_name,
        layer_key,
        docs_flags,
        docs_working_directory,
        source_path_mappings,
      ).perform
    end

    private def create_library_docs_workspace(
      source_root : String,
      list_of_entrypoints : Array(String),
      standard_library_source_root : String,
    ) : CrystalDocsWorkspace
      source_path = File.expand_path(source_root)
      library_root = File.dirname(source_path)
      workspace_root = ""

      begin
        workspace_parent = File.join(@cache_root, "docs-workspaces")
        Dir.mkdir_p(workspace_parent)
        workspace_root = File.join(workspace_parent, "#{Process.pid}-#{Random::Secure.hex(12)}")
        Dir.mkdir_p(workspace_root)
        project_lib_path = File.join(@root_path, "lib")
        File.symlink(source_path, File.join(workspace_root, "src"))
        File.symlink(project_lib_path, File.join(workspace_root, "lib"))

        crystal_cache_path = File.join(workspace_root, "crystal-cache")
        Dir.mkdir_p(crystal_cache_path)
        list_of_workspace_entrypoints = list_of_entrypoints.map do |entrypoint|
          relative_entrypoint = entrypoint.sub(library_root + "/", "")
          File.join("src", relative_entrypoint.sub("src/", ""))
        end
        source_path_mappings = {
          File.join(workspace_root, "src") => source_path,
          File.join(workspace_root, "lib") => project_lib_path,
        }
        # The self-mapping makes the stdlib source root available to library ownership checks.
        source_path_mappings[standard_library_source_root] = standard_library_source_root

        CrystalDocsWorkspace.new(
          workspace_root,
          list_of_workspace_entrypoints,
          crystal_cache_path,
          source_path_mappings,
        )
      rescue ex : IO::Error
        FileUtils.rm_rf(workspace_root) unless workspace_root.empty?
        raise APIIndexBuildError.new("Could not create docs workspace for #{library_root}: #{ex.message}")
      end
    end

    private def standard_library_layer(cache : APIIndexCache, identity : CrystalAlphaIdentity) : CachedAPIIndexLayer
      layer_key = CalculateStandardLibraryLayerKey.new(identity.version).perform
      cached_layer = cache.load_layer("stdlib", "crystal", layer_key)
      return cached_layer if cached_layer.freshness == "fresh"

      begin
        source_root = crystal_source_root(identity)
        docs_flags = [] of String
        environment_overrides = {} of String => String
        if llvm_config = find_llvm_config(identity.llvm_version)
          environment_overrides["LLVM_CONFIG"] = llvm_config
        end

        docs_json = BuildCrystalDocsJSON.new(
          identity.executable_path,
          File.dirname(source_root),
          [File.join("src", "docs_main.cr")],
          "crystal",
          "0",
          docs_flags,
          environment_overrides,
        ).perform
        layer = NormalizeCrystalDocs.new(
          docs_json,
          File.dirname(source_root),
          "stdlib",
          "crystal",
          layer_key,
          docs_flags,
        ).perform
        cache.write_layer(layer)
        CachedAPIIndexLayer.new(layer, "fresh")
      rescue ex : APIIndexBuildError | JSON::ParseException | IO::Error
        return cached_layer if cached_layer.layer

        CachedAPIIndexLayer.new(nil, "unavailable", ex.message, "stdlib", "crystal", layer_key)
      end
    end

    private def crystal_source_root(identity : CrystalAlphaIdentity) : String
      output = IO::Memory.new
      error_output = IO::Memory.new
      status = Process.run(identity.executable_path, ["env", "CRYSTAL_PATH"], output: output, error: error_output)
      unless status.success?
        raise APIIndexBuildError.new("Could not locate the Crystal standard library: #{error_output.to_s.strip}")
      end

      source_root = output.to_s.strip.split(':').find do |path|
        next false if path == "lib"

        File.file?(File.join(path, "docs_main.cr"))
      end
      raise APIIndexBuildError.new("Could not locate src/docs_main.cr from crystal-alpha") unless source_root

      source_root
    rescue ex : IO::Error
      raise APIIndexBuildError.new("Could not locate the Crystal standard library: #{ex.message}")
    end

    private def find_llvm_config(llvm_version : String) : String?
      version_parts = llvm_version.split('.')
      major = version_parts.first?
      minor = version_parts[1]?
      return nil unless major && minor

      candidates = [] of String
      candidates << "/opt/homebrew/opt/llvm@#{major}/bin/llvm-config"
      candidates << "/usr/local/opt/llvm@#{major}/bin/llvm-config"

      if executable = Process.find_executable("llvm-config-#{major}.#{minor}")
        candidates << executable
      end
      if executable = Process.find_executable("llvm-config-#{major}")
        candidates << executable
      end
      if executable = Process.find_executable("llvm-config")
        candidates << executable
      end

      candidates.uniq.each do |candidate|
        next unless File.file?(candidate) || Process.find_executable(candidate)

        version_output = IO::Memory.new
        version_error = IO::Memory.new
        status = Process.run(candidate, ["--version"], output: version_output, error: version_error)
        next unless status.success?
        next unless version_output.to_s.strip.starts_with?("#{major}.#{minor}")

        return candidate
      rescue ex : IO::Error
        next
      end

      nil
    end

    private def relative_entrypoint(entrypoint : String, working_directory : String) : String
      return entrypoint unless Path[entrypoint].absolute?

      entrypoint.sub(File.expand_path(working_directory) + "/", "")
    end
  end
end
