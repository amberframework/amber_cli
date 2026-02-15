require "../spec_helper"

# Require all rule implementations so they auto-register
require "../../../src/amber_lsp/rules/controllers/*"
require "../../../src/amber_lsp/rules/jobs/*"
require "../../../src/amber_lsp/rules/channels/*"
require "../../../src/amber_lsp/rules/pipes/*"
require "../../../src/amber_lsp/rules/mailers/*"
require "../../../src/amber_lsp/rules/schemas/*"
require "../../../src/amber_lsp/rules/file_naming/*"
require "../../../src/amber_lsp/rules/routing/*"
require "../../../src/amber_lsp/rules/specs/*"
require "../../../src/amber_lsp/rules/sockets/*"

# Re-register all rules. This is needed because other spec files may call
# RuleRegistry.clear in their before_each blocks, removing the rules that
# were registered at require time. When running the full suite, the integration
# tests may execute after those clears have removed all rules.
private def register_all_rules : Nil
  AmberLSP::Rules::RuleRegistry.clear
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::InheritanceRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::BeforeActionRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::ActionReturnRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Jobs::PerformRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Jobs::SerializableRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Channels::HandleMessageRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Pipes::CallNextRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Mailers::RequiredMethodsRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Schemas::FieldTypeRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::SnakeCaseRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::DirectoryStructureRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Routing::ControllerActionExistenceRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Specs::SpecExistenceRule.new)
  AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Sockets::SocketChannelRule.new)
end

# Helper to create a temp Amber project directory with shard.yml
private def create_amber_project(dir : String) : Nil
  shard_content = <<-YAML
  name: test_project
  version: 0.1.0
  dependencies:
    amber:
      github: amberframework/amber
  YAML
  File.write(File.join(dir, "shard.yml"), shard_content)
end

# Helper to create a temp non-Amber project directory with shard.yml
private def create_non_amber_project(dir : String) : Nil
  shard_content = <<-YAML
  name: plain_project
  version: 0.1.0
  dependencies:
    kemal:
      github: kemalcr/kemal
  YAML
  File.write(File.join(dir, "shard.yml"), shard_content)
end

# Helper to build standard LSP initialize + initialized messages
private def initialize_messages(root_uri : String) : Array(Hash(String, String | Int32 | Hash(String, String)))
  [
    {
      "jsonrpc" => "2.0",
      "id"      => 1,
      "method"  => "initialize",
      "params"  => {
        "rootUri"      => root_uri,
        "capabilities" => {} of String => String,
      },
    },
    {
      "jsonrpc" => "2.0",
      "method"  => "initialized",
      "params"  => {} of String => String,
    },
  ]
end

# Helper to extract diagnostic notifications from responses
private def diagnostic_notifications(responses : Array(JSON::Any)) : Array(JSON::Any)
  responses.select { |r| r["method"]?.try(&.as_s?) == "textDocument/publishDiagnostics" }
end

# Helper to extract diagnostic codes from a publishDiagnostics notification
private def diagnostic_codes(notification : JSON::Any) : Array(String)
  notification["params"]["diagnostics"].as_a.map { |d| d["code"].as_s }
end

describe "LSP Integration: Full Lifecycle" do
  before_each { register_all_rules }

  it "completes a full initialize -> didOpen -> didSave -> didClose -> shutdown -> exit lifecycle" do
    with_tempdir do |dir|
      create_amber_project(dir)

      # Create the controllers directory for the file
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      bad_controller_content = <<-CRYSTAL
      class BadHandler < ApplicationController
        def index
          # TODO: fix this action
        end
      end
      CRYSTAL

      corrected_controller_content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      messages = [
        # 1. Initialize
        {
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        },
        # 2. Initialized notification
        {
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        },
        # 3. didOpen with invalid controller (bad naming + missing render)
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => bad_controller_content,
            },
          },
        },
        # 4. didSave with corrected version
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didSave",
          "params"  => {
            "textDocument" => {"uri" => file_uri},
            "text"         => corrected_controller_content,
          },
        },
        # 5. didClose
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didClose",
          "params"  => {
            "textDocument" => {"uri" => file_uri},
          },
        },
        # 6. Shutdown
        {
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        },
        # 7. Exit
        {
          "jsonrpc" => "2.0",
          "method"  => "exit",
        },
      ]

      responses = run_lsp_session(messages)

      # Verify initialize response
      init_response = responses[0]
      init_response["id"].as_i.should eq(1)
      init_response["result"]["serverInfo"]["name"].as_s.should eq("amber-lsp")
      init_response["result"]["capabilities"]["textDocumentSync"]["openClose"].as_bool.should be_true

      # Gather all diagnostic notifications
      diag_notifications = diagnostic_notifications(responses)

      # Should have at least 3 publishDiagnostics: didOpen, didSave, didClose
      diag_notifications.size.should be >= 3

      # First publishDiagnostics (from didOpen with bad controller)
      first_diag = diag_notifications[0]
      first_diag["params"]["uri"].as_s.should eq(file_uri)
      first_diag_codes = diagnostic_codes(first_diag)
      # BadHandler triggers controller-naming; missing render triggers action-return-type
      first_diag_codes.should contain("amber/controller-naming")
      first_diag_codes.should contain("amber/action-return-type")

      # Second publishDiagnostics (from didSave with corrected controller)
      second_diag = diag_notifications[1]
      second_diag["params"]["uri"].as_s.should eq(file_uri)
      second_diag_codes = diagnostic_codes(second_diag)
      # Corrected controller should NOT have naming or action-return-type violations
      second_diag_codes.should_not contain("amber/controller-naming")
      second_diag_codes.should_not contain("amber/action-return-type")

      # Third publishDiagnostics (from didClose) should be empty
      third_diag = diag_notifications[2]
      third_diag["params"]["uri"].as_s.should eq(file_uri)
      third_diag["params"]["diagnostics"].as_a.should be_empty

      # Verify shutdown response returns null result
      shutdown_response = responses.find { |r| r["id"]?.try(&.as_i?) == 2 }
      shutdown_response.should_not be_nil
      shutdown_response.not_nil!["result"].raw.should be_nil
    end
  end
end

describe "LSP Integration: Multi-Rule Diagnostics" do
  before_each { register_all_rules }

  it "triggers controller-naming, controller-inheritance, filter-syntax, and action-return-type" do
    with_tempdir do |dir|
      create_amber_project(dir)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      # This content is designed to trigger 4 specific rules:
      # 1. controller-naming: BadHandler does not end with Controller
      # 2. controller-inheritance: PostsController inherits from HTTP::Server (wrong parent)
      # 3. filter-syntax: before_action :authenticate uses Rails symbol syntax
      # 4. action-return-type: create method has no response method call
      multi_violation_content = <<-CRYSTAL
      class BadHandler < ApplicationController
        before_action :authenticate
        def create
          # TODO: implement this
        end
      end

      class PostsController < HTTP::Server
      end
      CRYSTAL

      messages = [
        {
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => multi_violation_content,
            },
          },
        },
        {
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "exit",
        },
      ]

      responses = run_lsp_session(messages)

      diag_notifications = diagnostic_notifications(responses)
      diag_notifications.size.should be >= 1

      codes = diagnostic_codes(diag_notifications[0])

      # All 4 specific rule violations must be present
      codes.should contain("amber/controller-naming")
      codes.should contain("amber/controller-inheritance")
      codes.should contain("amber/filter-syntax")
      codes.should contain("amber/action-return-type")

      # Verify each diagnostic has the correct structure
      diagnostics = diag_notifications[0]["params"]["diagnostics"].as_a

      diagnostics.each do |diag|
        diag["source"].as_s.should eq("amber-lsp")
        diag["range"]["start"]["line"].as_i.should be >= 0
        diag["range"]["start"]["character"].as_i.should be >= 0
        diag["range"]["end"]["line"].as_i.should be >= 0
        diag["range"]["end"]["character"].as_i.should be >= 0
        diag["severity"].as_i.should be >= 1
        diag["severity"].as_i.should be <= 4
      end
    end
  end
end

describe "LSP Integration: Non-Amber Project" do
  before_each { register_all_rules }

  it "produces no diagnostics for a non-Amber project" do
    with_tempdir do |dir|
      create_non_amber_project(dir)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      bad_code = <<-CRYSTAL
      class BadHandler < HTTP::Server
        before_action :authenticate
        def create
        end
      end
      CRYSTAL

      messages = [
        {
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didSave",
          "params"  => {
            "textDocument" => {"uri" => file_uri},
            "text"         => bad_code,
          },
        },
        {
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "exit",
        },
      ]

      responses = run_lsp_session(messages)

      # Should have only initialize and shutdown responses -- no publishDiagnostics
      diag_notifications = diagnostic_notifications(responses)
      diag_notifications.should be_empty
    end
  end
end

describe "LSP Integration: Job Rules" do
  before_each { register_all_rules }

  it "detects missing perform method and missing JSON::Serializable in job classes" do
    with_tempdir do |dir|
      create_amber_project(dir)
      Dir.mkdir_p(File.join(dir, "src", "jobs"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/jobs/bad_job.cr"

      bad_job_content = <<-CRYSTAL
      class BadJob < Amber::Jobs::Job
      end
      CRYSTAL

      messages = [
        {
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => bad_job_content,
            },
          },
        },
        {
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "exit",
        },
      ]

      responses = run_lsp_session(messages)

      diag_notifications = diagnostic_notifications(responses)
      diag_notifications.size.should be >= 1

      codes = diagnostic_codes(diag_notifications[0])
      codes.should contain("amber/job-perform")
      codes.should contain("amber/job-serializable")
    end
  end
end

describe "LSP Integration: Configuration Override" do
  before_each { register_all_rules }

  it "respects .amber-lsp.yml to disable specific rules" do
    with_tempdir do |dir|
      create_amber_project(dir)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      # Create config that disables controller-naming rule
      config_content = <<-YAML
      rules:
        amber/controller-naming:
          enabled: false
      YAML
      File.write(File.join(dir, ".amber-lsp.yml"), config_content)

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      # This content violates controller-naming (BadHandler) and filter-syntax (before_action :auth)
      bad_code = <<-CRYSTAL
      class BadHandler < ApplicationController
        before_action :authenticate
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      messages = [
        {
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => bad_code,
            },
          },
        },
        {
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        },
        {
          "jsonrpc" => "2.0",
          "method"  => "exit",
        },
      ]

      responses = run_lsp_session(messages)

      diag_notifications = diagnostic_notifications(responses)
      diag_notifications.size.should be >= 1

      codes = diagnostic_codes(diag_notifications[0])

      # controller-naming should NOT be present (disabled in config)
      codes.should_not contain("amber/controller-naming")

      # filter-syntax SHOULD still be present (not disabled)
      codes.should contain("amber/filter-syntax")
    end
  end
end
