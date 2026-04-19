require "json"
require "uri"

module AmberLSP
  class Controller
    @project_context : ProjectContext? = nil

    def initialize
      @document_store = DocumentStore.new
      @analyzer = Analyzer.new
    end

    def handle(raw_message : String, server : Server) : String?
      json = JSON.parse(raw_message)
      method = json["method"]?.try(&.as_s)
      id = json["id"]?

      case method
      when "initialize"
        handle_initialize(id, json)
      when "initialized"
        handle_initialized
      when "textDocument/didOpen"
        handle_did_open(json, server)
        nil
      when "textDocument/didSave"
        handle_did_save(json, server)
        nil
      when "textDocument/didClose"
        handle_did_close(json, server)
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
      error_response(JSON::Any.new(nil), -32700, "Parse error: #{ex.message}")
    end

    private def handle_initialize(id : JSON::Any?, json : JSON::Any) : String
      if params = json["params"]?
        if root_uri = params["rootUri"]?.try(&.as_s?)
          root_path = uri_to_path(root_uri)
          @project_context = ProjectContext.detect(root_path)
          if ctx = @project_context
            @analyzer.configure(ctx)
          end
        elsif root_path = params["rootPath"]?.try(&.as_s?)
          @project_context = ProjectContext.detect(root_path)
          if ctx = @project_context
            @analyzer.configure(ctx)
          end
        end
      end

      result = {
        "jsonrpc" => JSON::Any.new("2.0"),
        "id"      => id || JSON::Any.new(nil),
        "result"  => JSON::Any.new({
          "capabilities" => JSON::Any.new({
            "textDocumentSync" => JSON::Any.new({
              "openClose" => JSON::Any.new(true),
              "change"    => JSON::Any.new(1_i64), # Full sync
              "save"      => JSON::Any.new({
                "includeText" => JSON::Any.new(true),
              }),
            }),
          }),
          "serverInfo" => JSON::Any.new({
            "name"    => JSON::Any.new("amber-lsp"),
            "version" => JSON::Any.new(AmberLSP::VERSION),
          }),
        }),
      }

      result.to_json
    end

    private def handle_initialized : Nil
      # No-op: client acknowledged initialization
      nil
    end

    private def handle_did_open(json : JSON::Any, server : Server) : Nil
      params = json["params"]?
      return unless params

      text_document = params["textDocument"]?
      return unless text_document

      uri = text_document["uri"]?.try(&.as_s)
      text = text_document["text"]?.try(&.as_s)
      return unless uri && text

      @document_store.update(uri, text)
      run_diagnostics(uri, text, server)
    end

    private def handle_did_save(json : JSON::Any, server : Server) : Nil
      params = json["params"]?
      return unless params

      text_document = params["textDocument"]?
      return unless text_document

      uri = text_document["uri"]?.try(&.as_s)
      return unless uri

      text = params["text"]?.try(&.as_s)
      if text
        @document_store.update(uri, text)
        run_diagnostics(uri, text, server)
      elsif stored = @document_store.get(uri)
        run_diagnostics(uri, stored, server)
      end
    end

    private def handle_did_close(json : JSON::Any, server : Server) : Nil
      params = json["params"]?
      return unless params

      text_document = params["textDocument"]?
      return unless text_document

      uri = text_document["uri"]?.try(&.as_s)
      return unless uri

      @document_store.remove(uri)
      publish_diagnostics(uri, [] of Rules::Diagnostic, server)
    end

    private def handle_shutdown(id : JSON::Any?) : String
      result = {
        "jsonrpc" => JSON::Any.new("2.0"),
        "id"      => id || JSON::Any.new(nil),
        "result"  => JSON::Any.new(nil),
      }
      result.to_json
    end

    private def handle_exit(server : Server) : Nil
      server.stop
    end

    private def error_response(id : JSON::Any?, code : Int32, message : String) : String
      result = {
        "jsonrpc" => JSON::Any.new("2.0"),
        "id"      => id || JSON::Any.new(nil),
        "error"   => JSON::Any.new({
          "code"    => JSON::Any.new(code.to_i64),
          "message" => JSON::Any.new(message),
        }),
      }
      result.to_json
    end

    private def run_diagnostics(uri : String, content : String, server : Server) : Nil
      file_path = uri_to_path(uri)

      # Only analyze Crystal files
      return unless file_path.ends_with?(".cr")

      # Only run if we detected an Amber project
      ctx = @project_context
      return unless ctx && ctx.amber_project?

      diagnostics = @analyzer.analyze(file_path, content)
      publish_diagnostics(uri, diagnostics, server)
    end

    private def publish_diagnostics(uri : String, diagnostics : Array(Rules::Diagnostic), server : Server) : Nil
      lsp_diagnostics = diagnostics.map(&.to_lsp_json)

      notification = {
        "jsonrpc" => JSON::Any.new("2.0"),
        "method"  => JSON::Any.new("textDocument/publishDiagnostics"),
        "params"  => JSON::Any.new({
          "uri"         => JSON::Any.new(uri),
          "diagnostics" => JSON::Any.new(lsp_diagnostics.map { |d| JSON::Any.new(d) }),
        }),
      }

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
