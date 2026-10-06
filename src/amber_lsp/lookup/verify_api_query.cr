require "file_utils"
require "process"
require "path"
require "random/secure"
require "set"
require "yaml"

require "./index_models"
require "./index_cache"
require "./resolve_api_query"
require "./source_models"

module AmberLSP::Lookup
  struct APIProbeResult
    getter status : String
    getter elapsed_milliseconds : Int64
    getter output : String
    getter verified_entry : APIIndexMethod?

    def initialize(
      @status : String,
      @elapsed_milliseconds : Int64,
      @output : String,
      @verified_entry : APIIndexMethod? = nil,
    )
    end
  end

  class VerifyAPIQuery
    def initialize(
      @project_root_path : String,
      @query : String,
      @resolution : APIResolution,
      @compiler_command : String = "crystal-alpha",
    )
      @project_root_path = File.expand_path(@project_root_path)
    end

    def perform : APIProbeResult
      started_at = Time.instant
      compiler_path = Process.find_executable(@compiler_command)
      return unavailable(started_at, "crystal-alpha is not available on PATH") unless compiler_path

      target = verification_target
      if target
        return run_probe(started_at, compiler_path, target)
      end

      return verify_candidates(started_at, compiler_path) if @resolution.resolution_kind == "bare_method"

      unavailable(started_at, "The query cannot be represented safely in a Crystal probe")
    rescue ex : Exception
      APIProbeResult.new("unavailable", elapsed_milliseconds(started_at || Time.instant), ex.message || "Could not run the Crystal API probe")
    end

    private def verification_target : VerificationTarget?
      if match = @query.strip.match(/\A(.+)#([^.#]+)\z/)
        return VerificationTarget.new(match[1], match[2], "instance", nil) if safe_target?(match[1], match[2])
        return nil
      end

      if match = @query.strip.match(/\A(.+)\.([^.#]+)\z/)
        return VerificationTarget.new(match[1], match[2], "class", nil) if safe_target?(match[1], match[2])
        return nil
      end

      if @query.strip[0]?.try(&.uppercase?)
        type_name = @query.strip
        return VerificationTarget.new(type_name, nil, "type", nil) if safe_type_name?(type_name)
        return nil
      end

      nil
    end

    private def candidate_targets : Array(VerificationTarget)
      targets = [] of VerificationTarget
      seen_targets = Set(String).new
      @resolution.list_of_methods.each do |entry|
        next unless entry.name == @query.strip
        next if entry.method_kind == "macro"
        next unless safe_target?(entry.owner, entry.name)

        target_key = [entry.owner, entry.name, entry.method_kind].join("\0")
        next if seen_targets.includes?(target_key)

        seen_targets.add(target_key)
        targets << VerificationTarget.new(entry.owner, entry.name, entry.method_kind, entry)
      end
      targets
    end

    private def verify_candidates(started_at : Time::Instant, compiler_path : String) : APIProbeResult
      targets = candidate_targets
      return unavailable(started_at, "The index returned no safe candidates for this query") if targets.empty?

      targets.each do |target|
        result = run_probe(started_at, compiler_path, target)
        return result if result.status == "present" || result.status == "unavailable"
      end

      unavailable(started_at, "No indexed candidate was verified; the compiler cannot establish global absence for a bare method")
    end

    private def run_probe(
      started_at : Time::Instant,
      compiler_path : String,
      target : VerificationTarget,
    ) : APIProbeResult
      probe_root : String? = nil
      entrypoint = project_entrypoint
      probe_root = File.join(@project_root_path, ".amber-lsp-probe-#{Random::Secure.hex(10)}")
      cache_path = File.join(probe_root, "cache")
      probe_path = File.join(probe_root, "probe.cr")
      Dir.mkdir_p(cache_path)
      relative_entrypoint = Path[entrypoint].relative_to(@project_root_path).to_s
      require_path = File.join("..", relative_entrypoint).sub(/\.cr\z/, "")
      File.write(probe_path, probe_source(require_path, target))

      output = IO::Memory.new
      error_output = IO::Memory.new
      status = Process.run(
        compiler_path,
        ["build", "--no-codegen", probe_path],
        chdir: @project_root_path,
        env: {"CRYSTAL_CACHE_DIR" => cache_path},
        output: output,
        error: error_output,
      )
      compiler_output = [output.to_s, error_output.to_s].reject(&.empty?).join("\n").strip

      if status.success?
        APIProbeResult.new("present", elapsed_milliseconds(started_at), compiler_output, target.verified_entry)
      elsif compiler_output.includes?(ABSENT_MARKER)
        APIProbeResult.new("absent", elapsed_milliseconds(started_at), compiler_output)
      else
        APIProbeResult.new("unavailable", elapsed_milliseconds(started_at), compiler_output)
      end
    rescue ex : Exception
      unavailable(started_at, ex.message || "Could not run the Crystal API probe")
    ensure
      FileUtils.rm_rf(probe_root) if probe_root
    end

    private def safe_target?(type_name : String, method_name : String) : Bool
      safe_type_name?(type_name) && method_name.matches?(/\A[a-zA-Z_][a-zA-Z0-9_]*[!?]?\z/)
    end

    private def safe_type_name?(type_name : String) : Bool
      type_name.matches?(/\A(?:::)?[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*(?:\([A-Za-z0-9_:, ?|&]+\))?\z/)
    end

    private def project_entrypoint : String
      manifest_path = File.join(@project_root_path, "shard.yml")
      manifest = File.file?(manifest_path) ? ProjectShardManifest.from_yaml(File.read(manifest_path)) : ProjectShardManifest.new

      manifest.targets.values.map(&.main).reject(&.empty?).sort.each do |entrypoint|
        return File.expand_path(entrypoint, @project_root_path) if File.file?(File.expand_path(entrypoint, @project_root_path))
      end

      unless manifest.name.empty?
        entrypoint = File.join(@project_root_path, "src", "#{manifest.name.gsub('-', '_')}.cr")
        return entrypoint if File.file?(entrypoint)
      end

      {"config/application.cr", "src/application.cr"}.each do |relative_path|
        entrypoint = File.join(@project_root_path, relative_path)
        return entrypoint if File.file?(entrypoint)
      end

      first_source = Dir.glob(File.join(@project_root_path, "src", "*.cr")).sort.first?
      raise APIIndexBuildError.new("No Crystal entrypoint found under #{@project_root_path}/src") unless first_source

      first_source
    end

    private def probe_source(require_path : String, target : VerificationTarget) : String
      source = String::Builder.new
      source << "require " << require_path.inspect << "\n"
      source << <<-CRYSTAL
        macro amber_lsp_verify_type(type_expression)
          {% type_node = parse_type(type_expression.stringify).resolve? %}
          {% unless type_node.is_a?(TypeNode) %}
            {% raise "#{ABSENT_MARKER}" %}
          {% end %}
          nil
        end

        macro amber_lsp_verify_method(type_expression, method_name, method_scope)
          {% type_node = parse_type(type_expression.stringify).resolve? %}
          {% unless type_node.is_a?(TypeNode) %}
            {% raise "#{ABSENT_MARKER}" %}
          {% end %}
          {% found = false %}
          {% if method_scope == :class %}
            {% for method in type_node.class.methods %}
              {% if method.name == method_name.id %}{% found = true %}{% end %}
            {% end %}
            {% for ancestor in type_node.ancestors %}
              {% for method in ancestor.class.methods %}
                {% if method.name == method_name.id %}{% found = true %}{% end %}
              {% end %}
            {% end %}
            {% for ancestor in type_node.class.ancestors %}
              {% for method in ancestor.methods %}
                {% if method.name == method_name.id %}{% found = true %}{% end %}
              {% end %}
            {% end %}
            {% for method in type_node.class.all_methods %}
              {% if method.name == method_name.id %}{% found = true %}{% end %}
            {% end %}
          {% else %}
            {% for method in type_node.methods %}
              {% if method.name == method_name.id %}{% found = true %}{% end %}
            {% end %}
            {% for ancestor in type_node.ancestors %}
              {% for method in ancestor.methods %}
                {% if method.name == method_name.id %}{% found = true %}{% end %}
              {% end %}
            {% end %}
            {% for method in type_node.all_methods %}
              {% if method.name == method_name.id %}{% found = true %}{% end %}
            {% end %}
          {% end %}
          {% unless found %}
            {% raise "#{ABSENT_MARKER}" %}
          {% end %}
          nil
        end
      CRYSTAL
      source << "\n"

      case target.target_kind
      when "type"
        source << "amber_lsp_verify_type(#{target.type_name})\n"
      when "class", "instance"
        method_scope = target.target_kind == "class" ? ":class" : ":instance"
        source << "amber_lsp_verify_method(#{target.type_name}, :#{target.method_name}, #{method_scope})\n"
      else
        raise APIIndexBuildError.new("Unsupported compiler probe target #{target.target_kind}")
      end

      source.to_s
    end

    private def unavailable(started_at : Time::Instant, reason : String) : APIProbeResult
      APIProbeResult.new("unavailable", elapsed_milliseconds(started_at), reason)
    end

    private def elapsed_milliseconds(started_at : Time::Instant) : Int64
      (Time.instant - started_at).total_milliseconds.to_i64
    end

    ABSENT_MARKER = "AMBER_LSP_PROBE_ABSENT"

    private struct VerificationTarget
      getter type_name : String
      getter method_name : String?
      getter target_kind : String
      getter verified_entry : APIIndexMethod?

      def initialize(@type_name : String, @method_name : String?, @target_kind : String, @verified_entry : APIIndexMethod?)
      end
    end
  end
end
