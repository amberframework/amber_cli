require "./spec_helper"
require "../../src/amber_lsp/rules/controllers/naming_rule"

describe AmberLSP::Controller do
  describe "#handle initialize" do
    it "returns server capabilities with correct structure" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      request = {
        "jsonrpc" => "2.0",
        "id"      => 1,
        "method"  => "initialize",
        "params"  => {
          "capabilities" => {} of String => String,
        },
      }.to_json

      response = server.controller.handle(request, server)
      response.should_not be_nil

      json = JSON.parse(response.not_nil!)
      json["jsonrpc"].as_s.should eq("2.0")
      json["id"].as_i.should eq(1)

      result = json["result"]
      capabilities = result["capabilities"]

      # Check textDocumentSync
      text_doc_sync = capabilities["textDocumentSync"]
      text_doc_sync["openClose"].as_bool.should be_true
      text_doc_sync["change"].as_i.should eq(1)
      text_doc_sync["save"]["includeText"].as_bool.should be_true

      # Check serverInfo
      server_info = result["serverInfo"]
      server_info["name"].as_s.should eq("amber-lsp")
      server_info["version"].as_s.should eq(AmberLSP::VERSION)
    end
  end

  describe "#handle didChange" do
    it "analyzes full-document unsaved content after didOpen" do
      with_tempdir do |project|
        Dir.mkdir_p(File.join(project, "src/controllers"))
        File.write(File.join(project, "shard.yml"), <<-YAML)
          name: amber_lsp_controller_spec
          version: 0.1.0
          dependencies:
            amber:
              github: amberframework/amber
        YAML

        file_path = File.join(project, "src/controllers/users_controller.cr")
        clean_content = <<-CRYSTAL
          # Serves the user pages.
          class UsersController < Amber::Controller::Base
          end
        CRYSTAL
        File.write(file_path, clean_content)
        uri = "file://#{file_path}"

        messages = [
          {"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {"rootUri" => "file://#{project}"}},
          {"jsonrpc" => "2.0", "method" => "initialized", "params" => {} of String => String},
          {"jsonrpc" => "2.0", "method" => "textDocument/didOpen", "params" => {"textDocument" => {"uri" => uri, "text" => clean_content}}},
          {"jsonrpc" => "2.0", "method" => "textDocument/didChange", "params" => {"textDocument" => {"uri" => uri, "version" => 2}, "contentChanges" => [{"text" => clean_content.gsub("UsersController", "UsersHandler")}]}},
          {"jsonrpc" => "2.0", "id" => 2, "method" => "shutdown"},
          {"jsonrpc" => "2.0", "method" => "exit"},
        ]

        AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
        responses = run_lsp_session(messages)
        diagnostics_notifications = responses.select do |response|
          response["method"]?.try(&.as_s?) == "textDocument/publishDiagnostics"
        end

        diagnostics_notifications.size.should eq(2)
        diagnostics_notifications[0]["params"]["diagnostics"].as_a.should be_empty
        changed_diagnostics = diagnostics_notifications[1]["params"]["diagnostics"].as_a
        changed_diagnostics.map { |diagnostic| diagnostic["code"].as_s }.should contain("amber/controller-naming")
        File.read(file_path).should eq(clean_content)
      end
    end
  end

  describe "#handle shutdown" do
    it "returns null result" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      request = {
        "jsonrpc" => "2.0",
        "id"      => 42,
        "method"  => "shutdown",
      }.to_json

      response = server.controller.handle(request, server)
      response.should_not be_nil

      json = JSON.parse(response.not_nil!)
      json["id"].as_i.should eq(42)
      json["result"].raw.should be_nil
    end
  end

  describe "#handle unknown method" do
    it "returns method not found error for unknown methods with id" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      request = {
        "jsonrpc" => "2.0",
        "id"      => 99,
        "method"  => "textDocument/hover",
      }.to_json

      response = server.controller.handle(request, server)
      response.should_not be_nil

      json = JSON.parse(response.not_nil!)
      json["error"]["code"].as_i.should eq(-32601)
      json["error"]["message"].as_s.should contain("Method not found")
    end

    it "returns nil for unknown notifications (no id)" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      request = {
        "jsonrpc" => "2.0",
        "method"  => "$/unknownNotification",
      }.to_json

      response = server.controller.handle(request, server)
      response.should be_nil
    end
  end

  describe "#handle invalid JSON" do
    it "returns parse error for malformed JSON" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      response = server.controller.handle("{invalid json}", server)
      response.should_not be_nil

      json = JSON.parse(response.not_nil!)
      json["error"]["code"].as_i.should eq(-32700)
      json["error"]["message"].as_s.should contain("Parse error")
    end
  end

  describe "#handle exit" do
    it "stops the server" do
      input = IO::Memory.new("")
      output = IO::Memory.new
      server = AmberLSP::Server.new(input, output)

      request = {
        "jsonrpc" => "2.0",
        "method"  => "exit",
      }.to_json

      response = server.controller.handle(request, server)
      response.should be_nil
    end
  end
end
