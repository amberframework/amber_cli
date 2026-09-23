require "./spec_helper"
require "../../src/amber_lsp/rules/controllers/action_return_rule"

GRANT_RULE_PACK_FIXTURE = <<-YAML
  pack: grant/tenancy
  library: grant
  version: 1.0.0
  modes:
    row:
      declared_by:
        key_path: grant.tenancy
        expected_value: row
      evidence:
        - '^\\s*multitenant\\b'
      tenant_column: tenant_id
      context: |
        Scope queries with Grant::Tenant.with.
    schema:
      declared_by:
        key_path: grant.tenancy
        expected_value: schema
      evidence:
        - '^\\s*Grant::SchemaTenant\\.with\\b'
        - '^\\s*schema_tenant_excluded\\b'
      context: |
        Schema-specific rules are not included yet.
  rules:
    - id: grant/tenant-column-without-multitenant
      modes: [row]
      severity: error
      applies_to: ["src/models/**"]
      message: Tenant columns require multitenant.
      check:
        kind: file_requires
        required_pattern: '^\\s*multitenant\\b'
    - id: grant/tenancy-modes-mixed
      modes: [row, schema]
      severity: error
      applies_to: ["**/*.cr"]
      message: Choose one tenancy mode.
      check:
        kind: project_conflict
        condition: mixed_modes
    - id: grant/row-query-outside-tenant
      modes: [row]
      severity: warning
      applies_to: ["**/*.cr"]
      exclude_from: ["src/controllers/**"]
      message: Query must be tenant-scoped.
      check:
        kind: call_outside_block
        source_globs: ["src/models/**"]
        tenant_macro: multitenant
        methods: [all, where, find!]
        required_call: Grant::Tenant.with
        escape_call: unscoped
    - id: grant/unscoped-in-request-code
      modes: [row]
      severity: warning
      applies_to: ["src/controllers/**"]
      message: Do not use unscoped in request code.
      check:
        kind: line_regex
        pattern: '^\\s*[^#]*\\.unscoped\\b'
    - id: grant/raw-sql-on-scoped-model
      modes: [row]
      severity: warning
      applies_to: ["**/*.cr"]
      message: Raw SQL must use an unscoped block.
      check:
        kind: call_outside_block
        source_globs: ["src/models/**"]
        tenant_macro: multitenant
        methods: [exec, query, scalar]
        escape_call: unscoped
    - id: grant/tenancy-undeclared
      modes: [row]
      severity: warning
      applies_to: ["**/*.cr"]
      message: Declare Grant tenancy in shard.yml.
      check:
        kind: project_conflict
        condition: evidence_without_declaration
  YAML

def write_rule_pack_project(
  root : String,
  shard_content : String = "name: tenant_app\nversion: 0.1.0\ngrant:\n  tenancy: row\n",
  pack_content : String = GRANT_RULE_PACK_FIXTURE,
) : Nil
  Dir.mkdir_p(File.join(root, ".claude", "rules"))
  File.write(File.join(root, "shard.yml"), shard_content)
  File.write(File.join(root, ".claude", "rules", "tenancy.yml"), pack_content)
end

def analyze_pack_file(root : String, file_path : String, content : String) : Array(AmberLSP::Rules::Diagnostic)
  Dir.mkdir_p(File.dirname(file_path))
  File.write(file_path, content)
  project_context = AmberLSP::ProjectContext.detect(root)
  analyzer = AmberLSP::Analyzer.new
  analyzer.configure(project_context)
  analyzer.analyze(file_path, content)
end

def diagnostic_codes(diagnostics : Array(AmberLSP::Rules::Diagnostic)) : Array(String)
  diagnostics.map(&.code)
end

describe "AmberLSP library rule packs" do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  it "loads packs from installed dependencies and project rules" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      dependency_root = File.join(root, "dependency_source")
      dependency_pack_path = File.join(dependency_root, ".claude", "rules", "tenancy.yml")
      project_pack_path = File.join(root, ".claude", "rules", "project.yml")
      Dir.mkdir_p(File.dirname(dependency_pack_path))
      File.write(dependency_pack_path, GRANT_RULE_PACK_FIXTURE)
      Dir.mkdir_p(File.join(root, "lib"))
      File.symlink(dependency_root, File.join(root, "lib", "grant"))
      File.write(
        project_pack_path,
        GRANT_RULE_PACK_FIXTURE.gsub("grant/tenancy", "project/tenancy").gsub("library: grant", "library: project"),
      )

      project_context = AmberLSP::ProjectContext.detect(root)
      packs = AmberLSP::LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs

      packs.map(&.pack_id).should eq(["grant/tenancy", "project/tenancy"])
    end
  end

  it "keeps a library's own pack inactive while allowing clean LSP checks" do
    with_tempdir do |root|
      shard_content = "name: grant\nversion: 0.1.0\n"
      write_rule_pack_project(root, shard_content)

      project_context = AmberLSP::ProjectContext.detect(root)
      packs = AmberLSP::LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs
      packs.map(&.pack_id).should eq(["grant/tenancy"])

      file_path = File.join(root, "src", "grant", "scale", "tenant.cr")
      content = "multitenant :tenant_id\n"
      analyzer = AmberLSP::Analyzer.new
      analyzer.configure(project_context)
      analyzer.has_applicable_library_rule_pack?(file_path, content).should be_true
      analyzer.analyze(file_path, content).should be_empty
    end
  end

  it "runs a declared dependency pack in a non-Amber project" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "jobs"))
      file_path = File.join(root, "src", "jobs", "fixture.cr")
      diagnostics = analyze_pack_file(root, file_path, "puts \"unscoped\"\n")

      diagnostics.map(&.code).should eq([] of String)
    end
  end

  it "runs line_regex checks and ignores full-line comments" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      file_path = File.join(root, "src", "controllers", "todos_controller.cr")
      content = "# Todo.unscoped is only documentation\nTodo.unscoped.all\n"

      diagnostics = analyze_pack_file(root, file_path, content)

      diagnostics.map(&.code).should eq(["grant/unscoped-in-request-code"])
      diagnostics.first.range.start.line.should eq(1)
      diagnostics.first.severity.should eq(AmberLSP::Rules::Severity::Warning)
    end
  end

  it "reports a tenant column without multitenant and accepts the declared macro" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      file_path = File.join(root, "src", "models", "account.cr")
      Dir.mkdir_p(File.dirname(file_path))
      missing_macro = "class Account\n  column tenant_id : Int64\nend\n"

      diagnostics = analyze_pack_file(root, file_path, missing_macro)

      diagnostics.map(&.code).should contain("grant/tenant-column-without-multitenant")
      diagnostics.find(&.code.==("grant/tenant-column-without-multitenant")).not_nil!.severity.should eq(AmberLSP::Rules::Severity::Error)

      valid_model = "class Account\n  column tenant_id : Int64\n  multitenant :tenant_id\nend\n"
      valid_diagnostics = analyze_pack_file(root, file_path, valid_model)

      valid_diagnostics.map(&.code).should_not contain("grant/tenant-column-without-multitenant")
    end
  end

  it "uses the configured tenant column for file_requires" do
    with_tempdir do |root|
      pack_content = GRANT_RULE_PACK_FIXTURE.gsub("tenant_column: tenant_id", "tenant_column: account_id")
      write_rule_pack_project(root, pack_content: pack_content)
      file_path = File.join(root, "src", "models", "account.cr")
      Dir.mkdir_p(File.dirname(file_path))

      diagnostics = analyze_pack_file(root, file_path, "class Account\n  column account_id : Int64\nend\n")

      diagnostics.map(&.code).should contain("grant/tenant-column-without-multitenant")
    end
  end

  it "reports a multitenant query outside the required block" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))

      diagnostics = analyze_pack_file(root, file_path, "Todo.where(active: true)\n")

      diagnostics.map(&.code).should contain("grant/row-query-outside-tenant")
    end
  end

  it "accepts queries inside the required block and nested blocks" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))
      content = <<-CRYSTAL
        Grant::Tenant.with(7) do
          Todo.where(active: true)
          run do
            Todo.all
          end
        end
        CRYSTAL

      diagnostics = analyze_pack_file(root, file_path, content)

      diagnostics.map(&.code).should_not contain("grant/row-query-outside-tenant")
    end
  end

  it "does not treat a method defined inside a tenant block as scoped" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))
      content = <<-CRYSTAL
        Grant::Tenant.with(7) do
          def load_todos
            Todo.all
          end
        end
        CRYSTAL

      diagnostics = analyze_pack_file(root, file_path, content)

      diagnostics.map(&.code).should contain("grant/row-query-outside-tenant")
    end
  end

  it "does not scope a method body just because its call is inside a tenant block" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))
      content = <<-CRYSTAL
        def load_todos
          Todo.all
        end
        Grant::Tenant.with(7) { load_todos }
        CRYSTAL

      diagnostics = analyze_pack_file(root, file_path, content)

      diagnostics.map(&.code).should contain("grant/row-query-outside-tenant")
    end
  end

  it "allows a same-model unscoped block but not a different model's query" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      File.write(File.join(root, "src", "models", "invoice.cr"), "class Invoice\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))

      same_model = analyze_pack_file(root, file_path, "Todo.unscoped { Todo.where(active: true) }\n")
      same_model.map(&.code).should_not contain("grant/row-query-outside-tenant")

      different_model = analyze_pack_file(root, file_path, "Todo.unscoped { Invoice.all }\n")
      different_model.map(&.code).should contain("grant/row-query-outside-tenant")
    end
  end

  it "does not flag raw_all and allows raw SQL inside the same model's unscoped block" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      file_path = File.join(root, "src", "jobs", "cleanup_job.cr")
      Dir.mkdir_p(File.dirname(file_path))

      raw_all_diagnostics = analyze_pack_file(root, file_path, "Todo.raw_all(\"WHERE active = true\")\n")
      raw_all_diagnostics.map(&.code).should_not contain("grant/raw-sql-on-scoped-model")

      scoped_sql = <<-CRYSTAL
        Todo.unscoped do
          Todo.exec("DELETE FROM todos")
          Todo.query("SELECT 1") { }
          Todo.scalar("SELECT COUNT(*) FROM todos") { |value| value }
        end
        CRYSTAL
      scoped_sql_diagnostics = analyze_pack_file(root, file_path, scoped_sql)
      scoped_sql_diagnostics.map(&.code).should_not contain("grant/raw-sql-on-scoped-model")

      unsafe_sql = "Todo.exec(\"DELETE FROM todos\")\nTodo.query(\"SELECT 1\") { }\nTodo.scalar(\"SELECT 1\") { |value| value }\n"
      unsafe_sql_diagnostics = analyze_pack_file(root, file_path, unsafe_sql)
      unsafe_sql_diagnostics.count(&.code.==("grant/raw-sql-on-scoped-model")).should eq(3)
    end
  end

  it "reports mixed modes as an error and undeclared row use as a warning" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      file_path = File.join(root, "src", "jobs", "tenancy_job.cr")
      Dir.mkdir_p(File.dirname(file_path))
      mixed_content = "Grant::SchemaTenant.with(\"acme\") { run_job }\n"

      mixed_diagnostics = analyze_pack_file(root, file_path, mixed_content)
      mixed_diagnostic = mixed_diagnostics.find(&.code.==("grant/tenancy-modes-mixed")).not_nil!
      mixed_diagnostic.severity.should eq(AmberLSP::Rules::Severity::Error)

      shard_content = "name: tenant_app\nversion: 0.1.0\n"
      write_rule_pack_project(root, shard_content)
      Dir.mkdir_p(File.join(root, "src", "models"))
      File.write(File.join(root, "src", "models", "todo.cr"), "class Todo\n  multitenant :tenant_id\nend\n")
      undeclared_path = File.join(root, "src", "jobs", "undeclared_job.cr")
      undeclared_diagnostics = analyze_pack_file(root, undeclared_path, "Todo.all\n")
      undeclared = undeclared_diagnostics.find(&.code.==("grant/tenancy-undeclared")).not_nil!
      undeclared.severity.should eq(AmberLSP::Rules::Severity::Warning)
    end
  end

  it "keeps Amber built-in rules gated on Amber dependencies" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      file_path = File.join(root, "src", "controllers", "home_controller.cr")
      Dir.mkdir_p(File.dirname(file_path))
      content = "class HomeController < ApplicationController\n  def index\n    User.all\n  end\nend\n"
      AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::ActionReturnRule.new)
      non_amber_analyzer = AmberLSP::Analyzer.new
      non_amber_analyzer.configure(AmberLSP::ProjectContext.detect(root))

      non_amber_diagnostics = non_amber_analyzer.analyze(file_path, content)
      non_amber_diagnostics.map(&.code).should_not contain("amber/action-return-type")

      shard_content = <<-YAML
        name: tenant_app
        version: 0.1.0
        grant:
          tenancy: row
        dependencies:
          amber:
            github: amberframework/amber
        YAML
      File.write(File.join(root, "shard.yml"), shard_content)
      amber_analyzer = AmberLSP::Analyzer.new
      amber_analyzer.configure(AmberLSP::ProjectContext.detect(root))

      amber_diagnostics = amber_analyzer.analyze(file_path, content)
      amber_diagnostics.map(&.code).should contain("amber/action-return-type")
    end
  end

  it "prints declared context and warns when feature use has no declaration" do
    with_tempdir do |root|
      write_rule_pack_project(root)
      file_path = File.join(root, "src", "models", "todo.cr")
      Dir.mkdir_p(File.dirname(file_path))
      File.write(file_path, "class Todo\n  multitenant :tenant_id\nend\n")
      binary_path = File.join(Dir.current, "bin", "amber-lsp")
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(binary_path, ["context", "--root", root], output: stdout, error: stderr)

      status.success?.should be_true
      stderr.to_s.should be_empty
      stdout.to_s.should contain("grant/tenancy (row)")
      stdout.to_s.should contain("Scope queries with Grant::Tenant.with.")

      undeclared_shard = "name: tenant_app\nversion: 0.1.0\n"
      write_rule_pack_project(root, undeclared_shard)
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(binary_path, ["context", "--root", root], output: stdout, error: stderr)

      status.success?.should be_true
      stdout.to_s.should contain("warning: grant/tenancy feature is used but shard.yml does not declare grant.tenancy.")
    end
  end

  it "prints nothing when no pack is declared or evidenced" do
    with_tempdir do |root|
      File.write(File.join(root, "shard.yml"), "name: empty_app\nversion: 0.1.0\n")
      binary_path = File.join(Dir.current, "bin", "amber-lsp")
      stdout = IO::Memory.new
      status = Process.run(binary_path, ["context", "--root", root], output: stdout, error: Process::Redirect::Close)

      status.success?.should be_true
      stdout.to_s.should be_empty
    end
  end
end
