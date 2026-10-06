require "digest/sha256"
require "process"
require "yaml"

require "./build_crystal_docs_json"
require "./index_cache"
require "./normalize_crystal_docs"
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
      identity = DetectCrystalAlpha.new(@compiler_command).perform
      cache = APIIndexCache.new(@cache_root, @root_path)
      list_of_layers = [] of CachedAPIIndexLayer
      project_name = manifest.name.empty? ? File.basename(@root_path) : manifest.name
      project_flags = docs_flags_for(project_name)
      project_key = CalculateProjectLayerKey.new(@root_path, project_flags, identity.version).perform
      project_entrypoint = find_project_entrypoint(manifest)

      list_of_layers << build_or_load_layer(
        cache,
        identity,
        "project",
        project_name,
        project_key,
        @root_path,
        project_flags,
        project_entrypoint,
        @root_path,
        {} of String => String,
      )

      locked_shards = read_locked_shards
      if !locked_shards.empty?
        project_crystal_path = crystal_path_for_project_libraries(identity)
      else
        project_crystal_path = nil
      end

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

        entrypoint = find_library_entrypoint(library_root, library_name)
        unless entrypoint
          list_of_layers << CachedAPIIndexLayer.new(
            nil,
            "unavailable",
            "Locked shard #{library_name} has no Crystal entrypoint under lib/#{library_name}/src",
            "library",
            library_name,
            locked_shard.version,
          )
          next
        end

        docs_flags = docs_flags_for(library_name)
        layer_key = CalculateLibraryLayerKey.new(library_name, locked_shard.version, docs_flags, identity.version).perform
        environment_overrides = {"CRYSTAL_PATH" => project_crystal_path || ""}

        list_of_layers << build_or_load_layer(
          cache,
          identity,
          "library",
          library_name,
          layer_key,
          library_root,
          docs_flags,
          entrypoint,
          library_root,
          environment_overrides,
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

    private def find_library_entrypoint(library_root : String, library_name : String) : String?
      source_root = File.join(library_root, "src")
      return nil unless File.directory?(source_root)

      conventional_name = library_name.gsub('-', '_')
      conventional_entrypoint = File.join(source_root, "#{conventional_name}.cr")
      return conventional_entrypoint if File.file?(conventional_entrypoint)

      Dir.glob(File.join(source_root, "*.cr")).sort.first? || Dir.glob(File.join(source_root, "**", "*.cr")).sort.first?
    end

    private def docs_flags_for(library_name : String) : Array(String)
      @list_of_docs_flags_by_library[library_name]?.try(&.sort) || [] of String
    end

    private def build_or_load_layer(
      cache : APIIndexCache,
      identity : CrystalAlphaIdentity,
      layer_kind : String,
      layer_name : String,
      layer_key : String,
      source_root : String,
      docs_flags : Array(String),
      entrypoint : String,
      working_directory : String,
      environment_overrides : Hash(String, String),
    ) : CachedAPIIndexLayer
      cached_layer = cache.load_layer(layer_kind, layer_name, layer_key)
      return cached_layer if cached_layer.freshness == "fresh"

      begin
        docs_json = BuildCrystalDocsJSON.new(
          identity.executable_path,
          working_directory,
          relative_entrypoint(entrypoint, working_directory),
          layer_name,
          "0",
          docs_flags,
          environment_overrides,
        ).perform
        layer = NormalizeCrystalDocs.new(
          docs_json,
          source_root,
          layer_kind,
          layer_name,
          layer_key,
          docs_flags,
        ).perform
        cache.write_layer(layer)
        CachedAPIIndexLayer.new(layer, "fresh")
      rescue ex : APIIndexBuildError | JSON::ParseException
        return cached_layer if cached_layer.layer

        CachedAPIIndexLayer.new(nil, "unavailable", ex.message, layer_kind, layer_name, layer_key)
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
          File.join("src", "docs_main.cr"),
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

    private def crystal_path_for_project_libraries(identity : CrystalAlphaIdentity) : String
      output = IO::Memory.new
      error_output = IO::Memory.new
      status = Process.run(identity.executable_path, ["env", "CRYSTAL_PATH"], output: output, error: error_output)
      unless status.success?
        raise APIIndexBuildError.new("Could not read crystal-alpha CRYSTAL_PATH: #{error_output.to_s.strip}")
      end
      "#{output.to_s.strip}:#{File.join(@root_path, "lib")}"
    rescue ex : IO::Error
      raise APIIndexBuildError.new("Could not read crystal-alpha CRYSTAL_PATH: #{ex.message}")
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
