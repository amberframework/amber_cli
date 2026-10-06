require "json"

require "./answer_api_query"
require "./build_layered_api_index"
require "./resolve_api_query"
require "./verify_api_query"

module AmberLSP::Lookup
  struct LookupCLIOptions
    getter query : String?
    getter at_location : String?
    getter root_path : String
    getter json : Bool
    getter verify : Bool

    def initialize(
      @query : String?,
      @at_location : String?,
      @root_path : String,
      @json : Bool,
      @verify : Bool,
    )
    end
  end

  struct LookupCLIAnswer
    include JSON::Serializable

    getter query : String
    getter status : String
    getter freshness : String
    @[JSON::Field(emit_null: true)]
    getter type_summary : APIIndexType?
    @[JSON::Field(key: "entries")]
    getter list_of_entries : Array(APIIndexMethod)
    @[JSON::Field(key: "layers")]
    getter list_of_layers : Array(APIIndexLayerState)
    @[JSON::Field(emit_null: true)]
    getter verification_status : String?
    @[JSON::Field(emit_null: true)]
    getter verification_elapsed_milliseconds : Int64?
    @[JSON::Field(emit_null: true)]
    getter failure_reason : String?

    def initialize(
      @query : String,
      @status : String,
      @freshness : String,
      @type_summary : APIIndexType?,
      @list_of_entries : Array(APIIndexMethod),
      @list_of_layers : Array(APIIndexLayerState),
      @verification_status : String?,
      @verification_elapsed_milliseconds : Int64?,
      @failure_reason : String?,
    )
    end
  end

  struct LookupAtQuery
    getter query : String
    getter token : String
    getter receiver : String?

    def initialize(@query : String, @token : String, @receiver : String?)
    end
  end

  class ExtractLookupQueryAtPosition
    def initialize(@source : String, @line_number : Int32, @column_number : Int32)
    end

    def perform : LookupAtQuery?
      return nil if @line_number < 0 || @column_number < 0

      line = @source.lines[@line_number]?.try(&.rstrip("\r\n"))
      return nil unless line

      column = Math.min(@column_number, line.bytesize)
      before_cursor = line.byte_slice(0, column)
      after_cursor = line.byte_slice(column, line.bytesize - column)
      left_token = before_cursor.match(/[A-Za-z0-9_!?]+\z/).try(&.[0]) || ""
      right_token = after_cursor.match(/\A[A-Za-z0-9_!?]+/).try(&.[0]) || ""
      token = left_token + right_token
      return nil if token.empty?

      receiver_prefix = before_cursor.byte_slice(0, before_cursor.bytesize - left_token.bytesize)
      receiver_match = receiver_prefix.match(/(.+)([.#])\s*\z/)
      return LookupAtQuery.new(token, token, nil) unless receiver_match

      receiver = receiver_match[1].strip
      separator = receiver_match[2]
      if constant_receiver?(receiver)
        LookupAtQuery.new("#{receiver}#{separator}#{token}", token, receiver)
      else
        LookupAtQuery.new(token, token, receiver)
      end
    end

    private def constant_receiver?(receiver : String) : Bool
      receiver.matches?(/\A(?:::)?[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*(?:\([A-Za-z0-9_:, ?|&]+\))?\z/)
    end
  end

  class RunLookupCommand
    def initialize(
      @arguments : Array(String),
      @cache_root : String = APIIndexCache.default_root,
      @compiler_command : String = "crystal-alpha",
      @stdout : IO = STDOUT,
      @stderr : IO = STDERR,
    )
    end

    def perform : Int32
      options = parse_options
      query = lookup_query(options)
      cached_layers = BuildLayeredAPIIndex.new(
        options.root_path,
        @cache_root,
        {} of String => Array(String),
        @compiler_command,
      ).perform
      list_of_index_layers = cached_layers.compact_map(&.layer)
      resolution = ResolveAPIQuery.new(query, list_of_index_layers).perform
      answer = AnswerAPIQuery.new(query, resolution, cached_layers).perform
      probe = options.verify ? VerifyAPIQuery.new(options.root_path, query, resolution, @compiler_command).perform : nil
      cli_answer = make_cli_answer(answer, probe)

      if options.json
        @stdout.puts cli_answer.to_json
      else
        print_plain_answer(cli_answer, probe)
      end

      if probe && probe.status == "unavailable"
        @stderr.puts("amber-lsp lookup: verification unavailable: #{probe.output}")
        return 2
      end

      exit_code_for(cli_answer.status)
    rescue ex : Exception
      @stderr.puts("amber-lsp lookup failed: #{ex.message || "unknown error"}")
      2
    end

    private def parse_options : LookupCLIOptions
      query = nil.as(String?)
      at_location = nil.as(String?)
      root_path = Dir.current
      json = false
      verify = false
      index = 0

      while index < @arguments.size
        argument = @arguments[index]
        case argument
        when "--root"
          index += 1
          root_path = @arguments[index]? || raise ArgumentError.new("--root requires a directory")
        when "--at"
          index += 1
          at_location = @arguments[index]? || raise ArgumentError.new("--at requires FILE:LINE:COL")
        when "--json"
          json = true
        when "--verify"
          verify = true
        else
          if argument.starts_with?("-")
            raise ArgumentError.new("Unknown lookup option #{argument}")
          end
          raise ArgumentError.new("Only one lookup query is supported") if query
          query = argument
        end
        index += 1
      end

      raise ArgumentError.new("lookup requires a query or --at FILE:LINE:COL") if !query && !at_location
      raise ArgumentError.new("Use either a query or --at, not both") if query && at_location

      LookupCLIOptions.new(query, at_location, File.expand_path(root_path), json, verify)
    end

    private def lookup_query(options : LookupCLIOptions) : String
      return options.query.not_nil! if options.query

      at_location = options.at_location.not_nil!
      match = at_location.match(/\A(.+):(\d+):(\d+)\z/)
      raise ArgumentError.new("--at requires FILE:LINE:COL") unless match

      file_path = File.expand_path(match[1])
      line_number = match[2].to_i - 1
      column_number = match[3].to_i - 1
      raise ArgumentError.new("--at line and column numbers start at 1") if line_number < 0 || column_number < 0

      source = File.read(file_path)
      extracted = ExtractLookupQueryAtPosition.new(source, line_number, column_number).perform
      raise ArgumentError.new("No Crystal identifier at #{at_location}") unless extracted

      extracted.query
    end

    private def make_cli_answer(answer : LookupAnswer, probe : APIProbeResult?) : LookupCLIAnswer
      status = answer.status
      list_of_entries = answer.list_of_entries
      verification_status = probe.try(&.status)
      failure_reason = nil.as(String?)

      if probe
        case probe.status
        when "absent"
          status = "absent"
        when "present"
          if verified_entry = probe.verified_entry
            list_of_entries = [verified_entry]
            status = "found"
          elsif answer.status == "unknown"
            status = "present"
          end
        when "unavailable"
          failure_reason = probe.output
        end
      end

      LookupCLIAnswer.new(
        answer.query,
        status,
        answer.freshness,
        answer.type_summary,
        list_of_entries,
        answer.list_of_layers,
        verification_status,
        probe.try(&.elapsed_milliseconds),
        failure_reason,
      )
    end

    private def print_plain_answer(answer : LookupCLIAnswer, probe : APIProbeResult?) : Nil
      @stdout.puts("amber-lsp lookup: #{answer.status} (#{answer.freshness})")
      if type_summary = answer.type_summary
        @stdout.puts("#{type_summary.name} (#{type_summary.kind})  — #{type_summary.location_path}:#{type_summary.location_line}  [#{type_summary.source_layer}]")
      end

      answer.list_of_entries.each do |entry|
        argument_string = entry.args_string.starts_with?('(') ? entry.args_string : "(#{entry.args_string})"
        return_type = entry.return_type.gsub("::Nil", "Nil")
        @stdout.puts("#{entry.owner}##{entry.name}#{argument_string} : #{return_type}  — #{entry.source_path}:#{entry.source_line}  [#{entry.source_layer}]")
        @stdout.puts("  #{entry.doc_line}") if entry.doc_line
      end

      if probe
        @stderr.puts("amber-lsp lookup: verified #{probe.status} in #{probe.elapsed_milliseconds} ms")
      end
    end

    private def exit_code_for(status : String) : Int32
      case status
      when "found", "present"
        0
      when "candidates"
        3
      when "unknown"
        4
      when "absent"
        5
      else
        2
      end
    end
  end
end
