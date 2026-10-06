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
    getter list_of_verified_entries : Array(APIIndexMethod)
    getter verified_return_type : String?

    def initialize(
      @status : String,
      @elapsed_milliseconds : Int64,
      @output : String,
      @verified_entry : APIIndexMethod? = nil,
      @list_of_verified_entries : Array(APIIndexMethod) = [] of APIIndexMethod,
      @verified_return_type : String? = nil,
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
        if safe_target?(match[1], match[2])
          return VerificationTarget.new(match[1], match[2], "instance", nil, entries_named(match[2]))
        end
        return nil
      end

      if match = @query.strip.match(/\A(.+)\.([^.#]+)\z/)
        if safe_target?(match[1], match[2])
          return VerificationTarget.new(match[1], match[2], "class", nil, entries_named(match[2]))
        end
        return nil
      end

      if @query.strip[0]?.try(&.uppercase?)
        type_name = @query.strip
        return VerificationTarget.new(type_name, nil, "type", nil, [] of APIIndexMethod) if safe_type_name?(type_name)
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

        target_kind = entry.method_kind == "instance" ? "instance" : "class"
        target_key = [entry.owner, entry.name, target_kind].join("\0")
        next if seen_targets.includes?(target_key)

        seen_targets.add(target_key)
        targets << VerificationTarget.new(entry.owner, entry.name, target_kind, entry, [entry])
      end
      targets
    end

    private def entries_named(method_name : String) : Array(APIIndexMethod)
      @resolution.list_of_methods.select { |entry| entry.name == method_name }
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
        list_of_verified_entries, return_type_output = verify_return_types(
          compiler_path,
          probe_root,
          cache_path,
          require_path,
          target,
        )
        combined_output = [compiler_output, return_type_output.join("\n")].reject(&.empty?).join("\n")
        verified_entry = verified_candidate_entry(target, list_of_verified_entries)
        verified_return_type = list_of_verified_entries.compact_map(&.verified_return_type).first?
        APIProbeResult.new(
          "present",
          elapsed_milliseconds(started_at),
          combined_output,
          verified_entry,
          list_of_verified_entries,
          verified_return_type,
        )
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

    private def verify_return_types(
      compiler_path : String,
      probe_root : String,
      cache_path : String,
      require_path : String,
      target : VerificationTarget,
    ) : Tuple(Array(APIIndexMethod), Array(String))
      list_of_entries = [] of APIIndexMethod
      output_lines = [] of String
      return {list_of_entries, output_lines} unless target.method_name && !target.list_of_entries.empty?

      target.list_of_entries.each_with_index do |entry, index|
        if entry.macro?
          reason = "macros do not have a call-time return type"
          list_of_entries << entry.with_verification_skip_reason(reason)
          output_lines << "type check skipped: #{reason}"
          next
        end

        parsed_arguments = parse_argument_types(entry, target.type_name)
        if skip_reason = parsed_arguments.skip_reason
          list_of_entries << entry.with_verification_skip_reason(skip_reason)
          output_lines << "type check skipped: #{skip_reason}"
          next
        end

        call_expression = method_call_expression(target, entry, parsed_arguments.list_of_types.size)
        probe_path = File.join(probe_root, "type_probe_#{index}.cr")
        File.write(
          probe_path,
          return_type_probe_source(require_path, target, parsed_arguments.list_of_types, call_expression),
        )

        output = IO::Memory.new
        error_output = IO::Memory.new
        status = Process.run(
          compiler_path,
          ["run", probe_path],
          chdir: @project_root_path,
          env: {"CRYSTAL_CACHE_DIR" => cache_path},
          output: output,
          error: error_output,
        )
        compiler_output = [output.to_s, error_output.to_s].reject(&.empty?).join("\n").strip
        verified_type = status.success? ? verified_type_from(compiler_output) : nil
        if verified_type
          list_of_entries << entry.with_verified_return_type(verified_type)
          output_lines << "verified type: #{verified_type}"
        else
          reason = if status.success?
                     "compiler did not report a return type"
                   else
                     "compiler could not type-check this overload: #{compiler_output}"
                   end
          list_of_entries << entry.with_verification_skip_reason(reason)
          output_lines << "type check skipped: #{reason}"
        end
      end

      {list_of_entries, output_lines}
    end

    private def parse_argument_types(entry : APIIndexMethod, receiver_type_name : String) : ParsedArgumentTypes
      args_string = entry.args_string.strip
      return ParsedArgumentTypes.new([] of String) if args_string.empty? || args_string == "()"
      return ParsedArgumentTypes.new([] of String, "overload arguments could not be parsed") unless args_string.starts_with?('(') && args_string.ends_with?(')')

      argument_text = args_string.byte_slice(1, args_string.bytesize - 2)
      return ParsedArgumentTypes.new([] of String) if argument_text.strip.empty?

      list_of_types = [] of String
      split_method_arguments(argument_text).each do |argument|
        normalized_argument = argument.strip
        return ParsedArgumentTypes.new([] of String, "block parameters are unsupported") if normalized_argument.starts_with?('&')
        return ParsedArgumentTypes.new([] of String, "splat parameters are unsupported") if normalized_argument.starts_with?('*')

        match = normalized_argument.match(/\A[A-Za-z_][A-Za-z0-9_]*\s*:\s*(.+)\z/)
        return ParsedArgumentTypes.new([] of String, "parameters without declared types are unsupported") unless match

        declared_type = remove_default_argument(match[1]).strip
        return ParsedArgumentTypes.new([] of String, "parameters without declared types are unsupported") if declared_type.empty?

        resolved_type = ResolveAPIIndexReturnType.new(
          declared_type,
          receiver_type_name,
          entry.owner,
        ).perform
        return ParsedArgumentTypes.new([] of String, "parameter type could not be resolved") if resolved_type == UNKNOWN_API_RETURN_TYPE

        list_of_types << resolved_type
      end

      ParsedArgumentTypes.new(list_of_types)
    end

    private def split_method_arguments(arguments : String) : Array(String)
      list_of_arguments = [] of String
      current_argument = String::Builder.new
      delimiter_depth = 0
      quote : Char? = nil
      escaped = false

      arguments.each_char do |character|
        if active_quote = quote
          current_argument << character
          if escaped
            escaped = false
          elsif character == '\\'
            escaped = true
          elsif character == active_quote
            quote = nil
          end
          next
        end

        if character == '"' || character == '\''
          quote = character
          current_argument << character
          next
        end

        case character
        when '(', '[', '{' then delimiter_depth += 1
        when ')', ']', '}' then delimiter_depth -= 1 if delimiter_depth > 0
        when ','
          if delimiter_depth == 0
            list_of_arguments << current_argument.to_s.strip
            current_argument = String::Builder.new
            next
          end
        end
        current_argument << character
      end

      final_argument = current_argument.to_s.strip
      list_of_arguments << final_argument unless final_argument.empty?
      list_of_arguments
    end

    private def remove_default_argument(argument : String) : String
      delimiter_depth = 0
      argument.each_char_with_index do |character, index|
        case character
        when '(', '[', '{' then delimiter_depth += 1
        when ')', ']', '}' then delimiter_depth -= 1 if delimiter_depth > 0
        when '='
          return argument.byte_slice(0, index).to_s if delimiter_depth == 0
        end
      end
      argument
    end

    private def method_call_expression(
      target : VerificationTarget,
      entry : APIIndexMethod,
      argument_count : Int32,
    ) : String
      method_name = target.method_name || entry.name
      receiver_expression = if target.target_kind == "instance"
                              "amber_lsp_receiver"
                            else
                              target.type_name
                            end
      arguments = (0...argument_count).map { |index| "amber_lsp_argument_#{index}" }.join(", ")
      "#{receiver_expression}.#{method_name}(#{arguments})"
    end

    private def return_type_probe_source(
      require_path : String,
      target : VerificationTarget,
      list_of_argument_types : Array(String),
      call_expression : String,
    ) : String
      String.build do |source|
        source << "require " << require_path.inspect << "\n\n"
        if target.target_kind == "instance"
          source << "amber_lsp_receiver = uninitialized " << target.type_name << "\n"
        end
        list_of_argument_types.each_with_index do |type_name, index|
          source << "amber_lsp_argument_" << index.to_s << " = uninitialized (" << type_name << ")\n"
        end
        source << "puts \"AMBER_LSP_VERIFIED_TYPE: "
        source << '#'
        source << "{typeof("
        source << call_expression
        source << ")}\"\n"
      end
    end

    private def verified_type_from(compiler_output : String) : String?
      match = compiler_output.match(/AMBER_LSP_VERIFIED_TYPE:\s*(.+)/)
      return nil unless match

      verified_type = match[1].strip
      remove_outer_type_parentheses(verified_type)
    end

    private def remove_outer_type_parentheses(type_name : String) : String
      return type_name unless type_name.starts_with?('(') && type_name.ends_with?(')')

      depth = 0
      type_name.each_char_with_index do |character, index|
        case character
        when '(' then depth += 1
        when ')' then depth -= 1
        end
        return type_name if depth == 0 && index < type_name.size - 1
      end

      type_name.byte_slice(1, type_name.bytesize - 2).strip
    end

    private def verified_candidate_entry(
      target : VerificationTarget,
      list_of_verified_entries : Array(APIIndexMethod),
    ) : APIIndexMethod?
      verified_candidate = target.verified_entry
      return nil unless verified_candidate

      list_of_verified_entries.find do |entry|
        entry.owner == verified_candidate.owner &&
          entry.name == verified_candidate.name &&
          entry.args_string == verified_candidate.args_string &&
          entry.source_path == verified_candidate.source_path &&
          entry.source_line == verified_candidate.source_line
      end || verified_candidate
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
      getter list_of_entries : Array(APIIndexMethod)

      def initialize(
        @type_name : String,
        @method_name : String?,
        @target_kind : String,
        @verified_entry : APIIndexMethod?,
        @list_of_entries : Array(APIIndexMethod),
      )
      end
    end

    private struct ParsedArgumentTypes
      getter list_of_types : Array(String)
      getter skip_reason : String?

      def initialize(@list_of_types : Array(String), @skip_reason : String? = nil)
      end
    end
  end
end
