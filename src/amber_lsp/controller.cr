require "json"
require "set"
require "uri"

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

  struct IncomingParams
    include JSON::Serializable

    @[JSON::Field(key: "rootUri")]
    getter root_uri : String? = nil
    @[JSON::Field(key: "rootPath")]
    getter root_path : String? = nil
    @[JSON::Field(key: "textDocument")]
    getter text_document : IncomingTextDocument? = nil
    @[JSON::Field(key: "contentChanges")]
    getter content_changes : Array(IncomingContentChange)? = nil
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
    getter include_text : Bool = true

    def initialize
    end
  end

  # :nodoc:
  struct TextDocumentSyncOptions
    include JSON::Serializable

    @[JSON::Field(key: "openClose")]
    getter open_close : Bool = true
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

    def initialize(@text_document_sync : TextDocumentSyncOptions = TextDocumentSyncOptions.new)
    end
  end

  # :nodoc:
  struct ServerInfo
    include JSON::Serializable

    getter name : String = "amber-lsp"
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
    getter diagnostics : Array(Rules::LSPDiagnostic)

    def initialize(@uri : String, @diagnostics : Array(Rules::LSPDiagnostic))
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

    def initialize
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
      text = params.content_changes.try(&.last?).try(&.text)
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
