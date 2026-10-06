require "json"

require "./answer_api_query"
require "./build_layered_api_index"
require "./resolve_api_query"
require "./verify_api_query"
require "./extract_lookup_query_at_position"
require "./default_compiler_command"

module AmberLSP::Lookup
  struct LookupCLIOptions
    getter query : String?
    getter at_location : String?
    getter root_path : String
    getter should_output_json : Bool
    getter should_verify_api_query : Bool

    def initialize(
      @query : String?,
      @at_location : String?,
      @root_path : String,
      @should_output_json : Bool,
      @should_verify_api_query : Bool,
    )
    end
  end

  struct LookupCLIAnswer
    include JSON::Serializable

    getter query : String
    @[JSON::Field(key: "status")]
    getter lookup_status : String
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
    getter verified_return_type : String?
    @[JSON::Field(emit_null: true)]
    getter failure_reason : String?
    @[JSON::Field(key: "card_notes")]
    getter list_of_card_notes : Array(APICardNote)
    @[JSON::Field(key: "error_hints")]
    getter list_of_error_hints : Array(APICardErrorHint)
    @[JSON::Field(key: "api_card_errors")]
    getter list_of_api_card_errors : Array(String)

    def initialize(
      @query : String,
      @lookup_status : String,
      @freshness : String,
      @type_summary : APIIndexType?,
      @list_of_entries : Array(APIIndexMethod),
      @list_of_layers : Array(APIIndexLayerState),
      @verification_status : String?,
      @verification_elapsed_milliseconds : Int64?,
      @verified_return_type : String?,
      @failure_reason : String?,
      @list_of_card_notes : Array(APICardNote) = [] of APICardNote,
      @list_of_error_hints : Array(APICardErrorHint) = [] of APICardErrorHint,
      @list_of_api_card_errors : Array(String) = [] of String,
    )
    end
  end

  class RunLookupCommand
    USAGE = <<-TEXT
    Usage: amber-lsp lookup QUERY [--root DIR] [--json] [--verify]
           amber-lsp lookup --at FILE:LINE:COL [--root DIR] [--json] [--verify]

    Looks up a Crystal API in the project, its shards in lib/, and the standard library.
    QUERY is Type.method (class method), Type#method (instance method), or Type.

      --root DIR   project root (default: the current directory)
      --at LOC     look up the call at FILE:LINE:COL instead of a QUERY
      --json       print the answer as JSON
      --verify     compile a probe when the answer is unknown, to confirm the return type

    Exit codes: 0 found, 3 several candidates, 4 unknown, 5 absent, 2 failed.
    TEXT

    def initialize(
      @arguments : Array(String),
      @cache_root : String = APIIndexCache.default_root,
      @compiler_command : String = Lookup.default_compiler_command,
      @stdout : IO = STDOUT,
      @stderr : IO = STDERR,
    )
    end

    def perform : Int32
      if @arguments.includes?("--help") || @arguments.includes?("-h")
        @stdout.puts(USAGE)
        return 0
      end

      options = parse_options
      query = lookup_query(options)
      card_collection = LoadAPICards.new(options.root_path).perform
      cached_layers = BuildLayeredAPIIndex.new(
        options.root_path,
        @cache_root,
        {} of String => Array(String),
        @compiler_command,
      ).perform
      list_of_index_layers = cached_layers.compact_map(&.layer)
      resolution = ResolveAPIQuery.new(query, list_of_index_layers).perform
      answer = AnswerAPIQuery.new(query, resolution, cached_layers).perform
      probe = options.should_verify_api_query ? VerifyAPIQuery.new(options.root_path, query, resolution, @compiler_command).perform : nil
      note_list = card_collection.matching_notes(query)
      hint_list = probe.try(&.output).try { |output| card_collection.matching_error_hints(output) } || [] of APICardErrorHint
      cli_answer = make_cli_answer(answer, probe, note_list, hint_list, card_collection.list_of_errors)

      if options.should_output_json
        @stdout.puts cli_answer.to_json
      else
        print_plain_answer(cli_answer, probe)
      end

      if probe && probe.status == "unavailable"
        @stderr.puts("amber-lsp lookup: verification unavailable: #{probe.output}")
        return 2
      end

      exit_code_for(cli_answer.lookup_status)
    rescue ex : Exception
      @stderr.puts("amber-lsp lookup failed: #{ex.message || "unknown error"}")
      2
    end

    private def parse_options : LookupCLIOptions
      query : String? = nil
      at_location : String? = nil
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
      if query = options.query
        return query
      end

      at_location = options.at_location
      raise ArgumentError.new("lookup requires a query or --at FILE:LINE:COL") unless at_location
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

    private def make_cli_answer(
      answer : LookupAnswer,
      probe : APIProbeResult?,
      list_of_card_notes : Array(APICardNote),
      list_of_error_hints : Array(APICardErrorHint),
      list_of_api_card_errors : Array(String),
    ) : LookupCLIAnswer
      status = answer.status
      list_of_entries = answer.list_of_entries
      verification_status = probe.try(&.status)
      failure_reason : String? = nil

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
        list_of_entries = probe.list_of_verified_entries unless probe.list_of_verified_entries.empty?
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
        probe.try(&.verified_return_type),
        failure_reason,
        list_of_card_notes,
        list_of_error_hints,
        list_of_api_card_errors,
      )
    end

    private def print_plain_answer(answer : LookupCLIAnswer, probe : APIProbeResult?) : Nil
      @stdout.puts("amber-lsp lookup: #{answer.lookup_status} (#{answer.freshness})")
      if type_summary = answer.type_summary
        @stdout.puts("#{type_summary.name} (#{type_summary.kind})  — #{type_summary.location_path}:#{type_summary.location_line}  [#{type_summary.source_layer}]")
      end

      answer.list_of_entries.each do |entry|
        @stdout.puts("#{entry.lookup_signature}  — #{entry.source_path}:#{entry.source_line}  [#{entry.source_layer}]")
        @stdout.puts("  #{entry.doc_line}") if entry.doc_line
        @stdout.puts("  verified type: #{entry.verified_return_type}") if entry.verified_return_type
        @stdout.puts("  type check skipped: #{entry.verification_skip_reason}") if entry.verification_skip_reason
      end

      answer.list_of_card_notes.each do |note|
        @stdout.puts("  Note [#{note.symbol}]: #{note.text}")
      end
      answer.list_of_error_hints.each do |hint|
        @stdout.puts("  Hint: #{hint.hint}")
        @stdout.puts("  Example: #{hint.example}")
      end

      answer.list_of_api_card_errors.each do |error|
        @stderr.puts("amber-lsp lookup: API card warning: #{error}")
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
