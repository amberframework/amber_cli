require "json"
require "set"
require "uri"

require "./lookup/api_cards"
require "./lookup/api_index_service"
require "./lookup/lsp_models"
require "./lookup/resolve_api_query"
require "./lookup/answer_api_query"
require "./lookup/extract_lookup_query_at_position"

module AmberLSP
  struct IncomingTextDocument
    include JSON::Serializable

    getter uri : String? = nil
    getter text : String? = nil
  end

  struct IncomingContentChange
    include JSON::Serializable

    getter text : String
  end

  struct IncomingPosition
    include JSON::Serializable

    getter line : Int32 = 0
    getter character : Int32 = 0
  end

  struct IncomingParams
    include JSON::Serializable

    @[JSON::Field(key: "rootUri")]
    getter root_uri : String? = nil
    @[JSON::Field(key: "rootPath")]
    getter root_path : String? = nil
    @[JSON::Field(key: "textDocument")]
    getter text_document : IncomingTextDocument? = nil
    @[JSON::Field(key: "contentChanges")]
    getter list_of_content_changes : Array(IncomingContentChange)? = nil
    getter position : IncomingPosition? = nil
    getter query : String? = nil
    getter text : String? = nil
  end

  struct IncomingMessage
    include JSON::Serializable

    getter method : String? = nil
    getter id : Int64 | String | Nil = nil
    getter params : IncomingParams? = nil
  end

  # :nodoc:
  struct SaveOptions
    include JSON::Serializable

    @[JSON::Field(key: "includeText")]
    getter should_include_text_on_save : Bool = true

    def initialize
    end
  end

  # :nodoc:
  struct TextDocumentSyncOptions
    include JSON::Serializable

    @[JSON::Field(key: "openClose")]
    getter can_open_and_close_documents : Bool = true
    getter change : Int32 = 1
    getter save : SaveOptions

    def initialize(@save : SaveOptions = SaveOptions.new)
    end
  end

  # :nodoc:
  struct ServerCapabilities
    include JSON::Serializable

    @[JSON::Field(key: "textDocumentSync")]
    getter text_document_sync : TextDocumentSyncOptions
    @[JSON::Field(key: "workspaceSymbolProvider")]
    getter can_provide_workspace_symbols : Bool = true
    @[JSON::Field(key: "hoverProvider")]
    getter can_provide_hover : Bool = true
    @[JSON::Field(key: "definitionProvider")]
    getter can_provide_definitions : Bool = true

    def initialize(
      @text_document_sync : TextDocumentSyncOptions = TextDocumentSyncOptions.new,
      @can_provide_workspace_symbols : Bool = true,
      @can_provide_hover : Bool = true,
      @can_provide_definitions : Bool = true,
    )
    end
  end

  # :nodoc:
  struct ServerInfo
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter server_name : String = "amber-lsp"
    getter version : String = AmberLSP::VERSION

    def initialize
    end
  end

  # :nodoc:
  struct InitializeResult
    include JSON::Serializable

    getter capabilities : ServerCapabilities
    @[JSON::Field(key: "serverInfo")]
    getter server_info : ServerInfo

    def initialize(@capabilities : ServerCapabilities = ServerCapabilities.new, @server_info : ServerInfo = ServerInfo.new)
    end
  end

  # :nodoc:
  struct InitializeResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    getter result : InitializeResult

    def initialize(@id : Int64 | String | Nil, @result : InitializeResult = InitializeResult.new)
    end
  end

  # :nodoc:
  struct ShutdownResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    @[JSON::Field(emit_null: true)]
    getter result : Nil = nil

    def initialize(@id : Int64 | String | Nil)
    end
  end

  # :nodoc:
  struct JsonRpcError
    include JSON::Serializable

    getter code : Int32
    getter message : String

    def initialize(@code : Int32, @message : String)
    end
  end

  # :nodoc:
  struct ErrorResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    getter error : JsonRpcError

    def initialize(@id : Int64 | String | Nil, @error : JsonRpcError)
    end
  end

  # :nodoc:
  struct PublishDiagnosticsParams
    include JSON::Serializable

    getter uri : String
    @[JSON::Field(key: "diagnostics")]
    getter list_of_diagnostics : Array(Rules::LSPDiagnostic)

    def initialize(@uri : String, @list_of_diagnostics : Array(Rules::LSPDiagnostic))
    end
  end

  # :nodoc:
  struct PublishDiagnosticsNotification
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    getter method : String = "textDocument/publishDiagnostics"
    getter params : PublishDiagnosticsParams

    def initialize(@params : PublishDiagnosticsParams)
    end
  end

  # :nodoc:
  struct LogMessageParams
    include JSON::Serializable

    getter type : Int32
    getter message : String

    def initialize(@type : Int32, @message : String)
    end
  end

  # :nodoc:
  struct LogMessageNotification
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    getter method : String = "window/logMessage"
    getter params : LogMessageParams

    def initialize(@params : LogMessageParams)
    end
  end

  class Controller
    @project_root_path : String? = nil
    @analyzer : Analyzer? = nil
    @last_coverage_status : String? = nil
    @uris_with_current_diagnostics = Set(String).new
    @roots_with_lookup_pending_message = Set(String).new

    def initialize(@lookup_index_service : Lookup::APIIndexService = Lookup::APIIndexService.new)
      @document_store = DocumentStore.new
    end

    def handle(raw_message : String, server : Server) : String?
      message = IncomingMessage.from_json(raw_message)
      method = message.method
      id = message.id

      case method
      when "initialize"
        handle_initialize(id, message.params)
      when "initialized"
        handle_initialized
      when "textDocument/didOpen"
        handle_did_open(message.params, server)
        nil
      when "textDocument/didChange"
        handle_did_change(message.params, server)
        nil
      when "textDocument/didSave"
        handle_did_save(message.params, server)
        nil
      when "textDocument/didClose"
        handle_did_close(message.params, server)
        nil
      when "workspace/symbol"
        handle_workspace_symbol(id, message.params, server)
      when "textDocument/hover"
        handle_hover(id, message.params, server)
      when "textDocument/definition"
        handle_definition(id, message.params, server)
      when "shutdown"
        handle_shutdown(id)
      when "exit"
        handle_exit(server)
        nil
      else
        if id
          error_response(id, -32601, "Method not found: #{method}")
        else
          nil
        end
      end
    rescue ex : JSON::ParseException
      error_response(nil, -32700, "Parse error: #{ex.message}")
    end

    private def handle_initialize(id : Int64 | String | Nil, params : IncomingParams?) : String
      if params
        if root_uri = params.root_uri
          set_project_root_path(uri_to_path(root_uri))
        elsif root_path = params.root_path
          set_project_root_path(root_path)
        end
      end

      InitializeResponse.new(id).to_json
    end

    private def handle_initialized : Nil
      # No-op: client acknowledged initialization
      nil
    end

    private def set_project_root_path(project_root_path : String) : Nil
      @project_root_path = project_root_path
    end

    private def handle_workspace_symbol(
      id : Int64 | String | Nil,
      params : IncomingParams?,
      server : Server,
    ) : String?
      return nil unless id

      query = params.try(&.query) || ""
      answer, card_collection, index_is_ready = answer_for_lookup(query)
      log_lookup_index_pending(server) unless index_is_ready
      list_of_symbols = [] of Lookup::LSPWorkspaceSymbol

      answer.list_of_entries.each do |entry|
        location = lsp_location(entry.source_path, entry.source_line)
        notes = card_collection.matching_notes(query)
        symbol_data = Lookup::LSPWorkspaceSymbolData.new(
          answer.status,
          answer.freshness,
          entry.source_layer,
          notes,
        )
        list_of_symbols << Lookup::LSPWorkspaceSymbol.new(
          "#{entry.owner}##{entry.name}#{entry.args_string}",
          6,
          location,
          entry.owner,
          symbol_data,
        )
      end

      if type_summary = answer.type_summary
        kind = case type_summary.kind
               when "class"  then 5
               when "module" then 2
               when "struct" then 23
               else               1
               end
        location = lsp_location(type_summary.location_path, type_summary.location_line)
        symbol_data = Lookup::LSPWorkspaceSymbolData.new(
          answer.status,
          answer.freshness,
          type_summary.source_layer,
          card_collection.matching_notes(query),
        )
        list_of_symbols << Lookup::LSPWorkspaceSymbol.new(
          type_summary.name,
          kind,
          location,
          nil,
          symbol_data,
        )
      end

      Lookup::LSPWorkspaceSymbolResponse.new(id, list_of_symbols).to_json
    end

    private def handle_hover(
      id : Int64 | String | Nil,
      params : IncomingParams?,
      server : Server,
    ) : String?
      return nil unless id

      extracted_query = query_at_position(params)
      return Lookup::LSPHoverResponse.new(id, nil).to_json unless extracted_query

      query = extracted_query[0]
      answer, card_collection, index_is_ready = answer_for_lookup(query)
      log_lookup_index_pending(server) unless index_is_ready
      markdown = hover_markdown(query, answer, card_collection)
      hover = Lookup::DescribeAPIForHover.new(Lookup::LSPMarkupContent.new(markdown))
      Lookup::LSPHoverResponse.new(id, hover).to_json
    end

    private def handle_definition(
      id : Int64 | String | Nil,
      params : IncomingParams?,
      server : Server,
    ) : String?
      return nil unless id

      extracted_query = query_at_position(params)
      return Lookup::LSPDefinitionResponse.new(id, nil).to_json unless extracted_query

      answer, _card_collection, index_is_ready = answer_for_lookup(extracted_query[0])
      unless index_is_ready
        log_lookup_index_pending(server)
        return Lookup::LSPDefinitionResponse.new(id, nil).to_json
      end

      list_of_locations = answer.list_of_entries.map do |entry|
        lsp_location(entry.source_path, entry.source_line)
      end
      if list_of_locations.empty?
        if type_summary = answer.type_summary
          list_of_locations << lsp_location(type_summary.location_path, type_summary.location_line)
        end
      end

      locations = list_of_locations.empty? ? nil : list_of_locations
      Lookup::LSPDefinitionResponse.new(id, locations).to_json
    end

    private def query_at_position(params : IncomingParams?) : Tuple(String, String)?
      return nil unless params
      text_document = params.text_document
      position = params.position
      return nil unless text_document && position
      uri = text_document.uri
      return nil unless uri

      content = @document_store.get(uri) || File.read(uri_to_path(uri))
      extracted = Lookup::ExtractLookupQueryAtPosition.new(content, position.line, position.character).perform
      extracted.try { |result| {result.query, uri} }
    rescue ex : IO::Error
      nil
    end

    private def answer_for_lookup(query : String) : Tuple(Lookup::LookupAnswer, Lookup::APICardCollection, Bool)
      project_root = @project_root_path || Dir.current
      cached_layers = @lookup_index_service.layers_for(project_root)
      card_collection = Lookup::LoadAPICards.new(project_root).perform

      if cached_layers
        @roots_with_lookup_pending_message.delete(project_root)
        list_of_index_layers = cached_layers.compact_map(&.layer)
        resolution = Lookup::ResolveAPIQuery.new(query, list_of_index_layers).perform
        answer = Lookup::AnswerAPIQuery.new(query, resolution, cached_layers).perform
        return {answer, card_collection, true}
      end

      layer_state = Lookup::APIIndexLayerState.new(
        "project",
        File.basename(project_root),
        "",
        "unavailable",
        "API index is being built in the background",
      )
      answer = Lookup::LookupAnswer.new(
        query,
        "unknown",
        "unavailable",
        nil,
        [] of Lookup::APIIndexMethod,
        [layer_state],
      )
      {answer, card_collection, false}
    end

    private def hover_markdown(
      query : String,
      answer : Lookup::LookupAnswer,
      card_collection : Lookup::APICardCollection,
    ) : String
      lines = [] of String
      answer.list_of_entries.each do |entry|
        argument_string = entry.args_string.starts_with?('(') ? entry.args_string : "(#{entry.args_string})"
        return_type = entry.return_type.gsub("::Nil", "Nil")
        lines << "```crystal"
        lines << "#{entry.owner}##{entry.name}#{argument_string} : #{return_type}"
        lines << "```"
        if doc_line = entry.doc_line
          lines << doc_line
        end
        lines << "Layer: #{entry.source_layer}"
      end

      if answer.list_of_entries.empty?
        if type_summary = answer.type_summary
          lines << "```crystal"
          lines << "#{type_summary.kind} #{type_summary.name}"
          lines << "```"
          lines << "Layer: #{type_summary.source_layer}"
        else
          lines << "```crystal"
          lines << (answer.freshness == "unavailable" ? "API index unavailable" : "No indexed API found for #{query}")
          lines << "```"
        end
      end

      lines << "Status: #{answer.status}"
      lines << "Freshness: #{answer.freshness}"
      card_collection.matching_notes(query).each do |note|
        lines << "Note (#{note.symbol}): #{note.text}"
      end
      lines.join("\n\n")
    end

    private def lsp_location(path : String, line_number : Int32) : Lookup::LSPLocation
      start_position = Lookup::LSPPosition.new(Math.max(line_number - 1, 0), 0)
      end_position = Lookup::LSPPosition.new(Math.max(line_number - 1, 0), 0)
      range = Lookup::LSPRange.new(start_position, end_position)
      Lookup::LSPLocation.new("file://#{URI.encode_path(path)}", range)
    end

    private def log_lookup_index_pending(server : Server) : Nil
      project_root = @project_root_path || Dir.current
      return if @roots_with_lookup_pending_message.includes?(project_root)

      @roots_with_lookup_pending_message.add(project_root)
      params = LogMessageParams.new(3, "amber-lsp: API index unavailable while a background build is running")
      server.write_notification(LogMessageNotification.new(params).to_json)
    end

    private def handle_did_open(params : IncomingParams?, server : Server) : Nil
      return unless params

      text_document = params.text_document
      return unless text_document

      uri = text_document.uri
      text = text_document.text
      return unless uri && text

      @document_store.update(uri, text)
      run_diagnostics(uri, text, server)
    end

    private def handle_did_change(params : IncomingParams?, server : Server) : Nil
      return unless params
      uri = params.text_document.try(&.uri)
      text = params.list_of_content_changes.try(&.last?).try(&.text)
      return unless uri && text

      @document_store.update(uri, text)
      run_diagnostics(uri, text, server)
    end

    private def handle_did_save(params : IncomingParams?, server : Server) : Nil
      return unless params

      text_document = params.text_document
      return unless text_document

      uri = text_document.uri
      return unless uri

      if project_root = @project_root_path
        @lookup_index_service.invalidate(project_root)
      end

      text = params.text
      if text
        @document_store.update(uri, text)
        run_diagnostics(uri, text, server)
      elsif stored = @document_store.get(uri)
        run_diagnostics(uri, stored, server)
      end
    end

    private def handle_did_close(params : IncomingParams?, server : Server) : Nil
      return unless params

      text_document = params.text_document
      return unless text_document

      uri = text_document.uri
      return unless uri

      @document_store.remove(uri)
      if @uris_with_current_diagnostics.includes?(uri)
        publish_diagnostics(uri, [] of Rules::Diagnostic, server)
        @uris_with_current_diagnostics.delete(uri)
      end
    end

    private def handle_shutdown(id : Int64 | String | Nil) : String
      ShutdownResponse.new(id).to_json
    end

    private def handle_exit(server : Server) : Nil
      server.stop
    end

    private def error_response(id : Int64 | String | Nil, code : Int32, message : String) : String
      ErrorResponse.new(id, JsonRpcError.new(code, message)).to_json
    end

    private def run_diagnostics(uri : String, content : String, server : Server) : Nil
      file_path = uri_to_path(uri)

      # Analyze Crystal source and the app-owned performance convention files.
      is_supported_analysis_file = file_path.ends_with?(".cr") ||
                                   file_path.ends_with?(".ecr") ||
                                   file_path.ends_with?(".slang") ||
                                   file_path.ends_with?(File.join("performance", "budget.json")) ||
                                   file_path.ends_with?(File.join("performance", "opt_out.json"))
      return unless is_supported_analysis_file

      analysis = AnalyzeFileWithCoverage.new(
        file_path,
        content,
        @project_root_path,
        @analyzer,
      )
      coverage = analysis.perform
      @analyzer = analysis.analysis_analyzer

      if coverage.is_a?(Coverage::Covered)
        publish_diagnostics(uri, coverage.list_of_diagnostics, server)
        @uris_with_current_diagnostics.add(uri)
        @last_coverage_status = nil
      elsif coverage.is_a?(Coverage::Declined)
        status_line = "amber-lsp: declined #{coverage.reason}"
        publish_coverage_status(uri, status_line, 2, server)
      elsif coverage.is_a?(Coverage::Failed)
        status_line = "amber-lsp: failed #{coverage.error}"
        publish_coverage_status(uri, status_line, 1, server)
      end
    end

    private def publish_coverage_status(uri : String, status_line : String, message_type : Int32, server : Server) : Nil
      return if @last_coverage_status == status_line

      if @uris_with_current_diagnostics.includes?(uri)
        publish_diagnostics(uri, [] of Rules::Diagnostic, server)
        @uris_with_current_diagnostics.delete(uri)
      end
      params = LogMessageParams.new(message_type, status_line)
      notification = LogMessageNotification.new(params)
      server.write_notification(notification.to_json)
      @last_coverage_status = status_line
    end

    private def publish_diagnostics(uri : String, diagnostics : Array(Rules::Diagnostic), server : Server) : Nil
      list_of_lsp_diagnostics = diagnostics.map(&.to_lsp_diagnostic)
      params = PublishDiagnosticsParams.new(uri, list_of_lsp_diagnostics)
      notification = PublishDiagnosticsNotification.new(params)
      server.write_notification(notification.to_json)
    end

    private def uri_to_path(uri : String) : String
      parsed = URI.parse(uri)
      if parsed.scheme == "file"
        URI.decode(parsed.path)
      else
        uri
      end
    end
  end
end
