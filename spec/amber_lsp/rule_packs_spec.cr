require "./spec_helper"

GRANT_TENANCY_PACK_FIXTURE_PATH = File.join(
  Dir.current,
  "spec",
  "fixtures",
  "rule_pack_apps",
  "row_app",
  "lib",
  "grant",
  ".amber-lsp",
  "packs",
  "tenancy.yml",
)

GRANT_TENANCY_REQUEST_PATHS = [
  "src/controllers/invoices_controller.cr",
  "src/channels/invoice_channel.cr",
  "src/sockets/invoice_socket.cr",
  "src/pipes/tenant_pipe.cr",
]

def install_tenancy_fixture_app(root : String, fixture_name : String) : Nil
  fixture_root = File.join(Dir.current, "spec", "fixtures", "rule_pack_apps", fixture_name)

  ["src", "config", "lib"].each do |directory_name|
    FileUtils.rm_rf(File.join(root, directory_name))
  end

  File.write(File.join(root, "shard.yml"), "name: #{fixture_name}\nversion: 0.1.0\n")

  ["src", "config"].each do |source_directory_name|
    source_directory = File.join(fixture_root, source_directory_name)
    next unless Dir.exists?(source_directory)

    FileUtils.cp_r(source_directory, root)
  end

  pack_path = File.join(root, "lib", "grant", ".amber-lsp", "packs", "tenancy.yml")
  Dir.mkdir_p(File.dirname(pack_path))
  File.write(pack_path, File.read(GRANT_TENANCY_PACK_FIXTURE_PATH))
end

def analyze_tenancy_fixture_source(
  root : String,
  relative_file_path : String,
  content : String,
) : Array(AmberLSP::Rules::Diagnostic)
  file_path = File.join(root, relative_file_path)
  Dir.mkdir_p(File.dirname(file_path))
  File.write(file_path, content)

  project_context = AmberLSP::ProjectContext.detect(root)
  analyzer = AmberLSP::Analyzer.new
  analyzer.configure(project_context)
  analyzer.analyze(file_path, content)
end

def has_tenancy_diagnostic_code?(diagnostics : Array(AmberLSP::Rules::Diagnostic), code : String) : Bool
  diagnostics.any? { |diagnostic| diagnostic.code == code }
end

def tenancy_diagnostic_codes(diagnostics : Array(AmberLSP::Rules::Diagnostic)) : Array(String)
  diagnostics.map(&.code)
end

describe "AmberLSP Grant tenancy rule pack v2" do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  it "loads the library pack from the harness-neutral dependency path" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      project_context = AmberLSP::ProjectContext.detect(root)
      list_of_rule_packs = AmberLSP::LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs

      list_of_rule_packs.map(&.pack_id).should eq(["grant/tenancy"])
      File.exists?(File.join(root, "lib", "grant", ".amber-lsp", "packs", "tenancy.yml")).should be_true
      File.exists?(File.join(root, "lib", "grant", ".claude", "rules", "tenancy.yml")).should be_false
    end
  end

  it "gives agents the Grant runtime context for detected modes" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")
      project_context = AmberLSP::ProjectContext.detect(root)
      rule_pack = AmberLSP::LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs.first

      rule_pack.should_not be_nil
      if loaded_rule_pack = rule_pack
        row_context = loaded_rule_pack.modes_by_name["row"].guidance_text
        row_context.should contain("detected from the app's `multitenant` model macros")
        row_context.should contain("ScopedRawSqlError")
        row_context.should contain("fiber-local")
        schema_context = loaded_rule_pack.modes_by_name["schema"].guidance_text
        schema_context.should contain("default search path without an error")
        schema_context.should contain("PostgreSQL")
      end
    end
  end

  it "loads exactly ten rules with only the two intended errors" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")
      project_context = AmberLSP::ProjectContext.detect(root)
      loaded_rule_pack = AmberLSP::LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs.first

      loaded_rule_pack.should_not be_nil
      if rule_pack = loaded_rule_pack
        rule_pack.list_of_rules.size.should eq(10)
        rule_pack.list_of_rules.count { |rule| rule.severity_name == "error" }.should eq(2)
        rule_pack.list_of_rules.count { |rule| rule.severity_name == "warning" }.should eq(8)
      end
    end
  end

  it "runs a pack in a non-Amber app and detects the account_id macro argument" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")
      project_context = AmberLSP::ProjectContext.detect(root)
      project_context.amber_project?.should be_false

      diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/controllers/invoices_controller.cr",
        "Invoice.unscoped.all\n",
      )

      has_tenancy_diagnostic_code?(diagnostics, "grant/chained-unscoped-in-request-code").should be_true
      diagnostics.any? do |diagnostic|
        diagnostic.code == "grant/chained-unscoped-in-request-code" &&
          diagnostic.severity == AmberLSP::Rules::Severity::Error
      end.should be_true
    end
  end

  it "reports chainable unscoped calls in each request path and allows block-form unscoped" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      GRANT_TENANCY_REQUEST_PATHS.each do |relative_path|
        diagnostics = analyze_tenancy_fixture_source(root, relative_path, "Invoice.unscoped.all\n")
        has_tenancy_diagnostic_code?(diagnostics, "grant/chained-unscoped-in-request-code").should be_true

        block_diagnostics = analyze_tenancy_fixture_source(
          root,
          relative_path,
          "Invoice.unscoped { Invoice.all }\n",
        )
        has_tenancy_diagnostic_code?(block_diagnostics, "grant/chained-unscoped-in-request-code").should be_false
      end
    end
  end

  it "reports unscoped bulk writes and leaves scoped writes clean" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      bulk_write_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/delete_invoices_job.cr",
        "Invoice.unscoped.delete_all\n",
      )
      has_tenancy_diagnostic_code?(bulk_write_diagnostics, "grant/chained-unscoped-bulk-write").should be_true
      bulk_write_diagnostics.any? do |diagnostic|
        diagnostic.code == "grant/chained-unscoped-bulk-write" && diagnostic.severity == AmberLSP::Rules::Severity::Error
      end.should be_true

      scoped_write_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/delete_invoices_job.cr",
        "Invoice.where(id: 1).delete_all\n",
      )
      has_tenancy_diagnostic_code?(scoped_write_diagnostics, "grant/chained-unscoped-bulk-write").should be_false

      spec_diagnostics = analyze_tenancy_fixture_source(
        root,
        "spec/delete_invoices_spec.cr",
        "Invoice.unscoped.update_all({\"status\" => \"archived\"})\n",
      )
      has_tenancy_diagnostic_code?(spec_diagnostics, "grant/chained-unscoped-bulk-write").should be_false

      db_diagnostics = analyze_tenancy_fixture_source(
        root,
        "db/backfill.cr",
        "Invoice.unscoped.delete_all\n",
      )
      has_tenancy_diagnostic_code?(db_diagnostics, "grant/chained-unscoped-bulk-write").should be_false
    end
  end

  it "warns about chainable unscoped reads outside request code and excludes bulk writes" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      read_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/read_invoices_job.cr", "Invoice.unscoped.all\n")
      has_tenancy_diagnostic_code?(read_diagnostics, "grant/chained-unscoped-on-tenant-model").should be_true

      request_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/controllers/invoices_controller.cr",
        "Invoice.unscoped.all\n",
      )
      has_tenancy_diagnostic_code?(request_diagnostics, "grant/chained-unscoped-on-tenant-model").should be_false

      write_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/delete_invoices_job.cr",
        "Invoice.unscoped.delete_all\n",
      )
      has_tenancy_diagnostic_code?(write_diagnostics, "grant/chained-unscoped-on-tenant-model").should be_false

      scoped_read_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/read_invoices_job.cr", "Invoice.all\n")
      has_tenancy_diagnostic_code?(scoped_read_diagnostics, "grant/chained-unscoped-on-tenant-model").should be_false
    end
  end

  it "warns about block-form unscoped in request code and allows the default scope" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      unsafe_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/controllers/invoices_controller.cr",
        "Invoice.unscoped { Invoice.all }\n",
      )
      has_tenancy_diagnostic_code?(unsafe_diagnostics, "grant/unscoped-block-in-request-code").should be_true

      safe_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/controllers/invoices_controller.cr",
        "Invoice.all\n",
      )
      has_tenancy_diagnostic_code?(safe_diagnostics, "grant/unscoped-block-in-request-code").should be_false
    end
  end

  it "warns when spawn is inside either tenant block and allows spawn outside" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")
      row_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/invoice_job.cr",
        "Grant::Tenant.with(7) { spawn { Invoice.all } }\n",
      )
      has_tenancy_diagnostic_code?(row_diagnostics, "grant/spawn-inside-tenant-block").should be_true

      outside_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/invoice_job.cr",
        "spawn { Invoice.all }\n",
      )
      has_tenancy_diagnostic_code?(outside_diagnostics, "grant/spawn-inside-tenant-block").should be_false

      install_tenancy_fixture_app(root, "schema_app")
      schema_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/invoice_job.cr",
        "Grant::SchemaTenant.with(\"acme\") { spawn { Invoice.all } }\n",
      )
      has_tenancy_diagnostic_code?(schema_diagnostics, "grant/spawn-inside-tenant-block").should be_true
    end
  end

  it "uses captured tenant columns and skips a model whose table the column references" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      missing_macro = File.read(File.join(
        Dir.current,
        "spec",
        "fixtures",
        "rule_pack_apps",
        "row_app",
        "src",
        "models",
        "invoice_export.cr",
      ))
      missing_diagnostics = analyze_tenancy_fixture_source(root, "src/models/invoice_export.cr", missing_macro)
      has_tenancy_diagnostic_code?(missing_diagnostics, "grant/tenant-column-without-multitenant").should be_true
      missing_diagnostics.any? do |diagnostic|
        diagnostic.code == "grant/tenant-column-without-multitenant" && diagnostic.message.includes?("account_id")
      end.should be_true

      declared_macro = missing_macro.sub("column account_id : Int64", "column account_id : Int64\n  multitenant :account_id")
      declared_diagnostics = analyze_tenancy_fixture_source(root, "src/models/invoice_export.cr", declared_macro)
      has_tenancy_diagnostic_code?(declared_diagnostics, "grant/tenant-column-without-multitenant").should be_false

      referenced_table = File.read(File.join(
        Dir.current,
        "spec",
        "fixtures",
        "rule_pack_apps",
        "row_app",
        "src",
        "models",
        "account.cr",
      ))
      referenced_diagnostics = analyze_tenancy_fixture_source(root, "src/models/account.cr", referenced_table)
      has_tenancy_diagnostic_code?(referenced_diagnostics, "grant/tenant-column-without-multitenant").should be_false

      unrelated_column = missing_macro.sub("account_id", "owner_id")
      unrelated_diagnostics = analyze_tenancy_fixture_source(root, "src/models/invoice_export.cr", unrelated_column)
      has_tenancy_diagnostic_code?(unrelated_diagnostics, "grant/tenant-column-without-multitenant").should be_false
    end
  end

  it "finds raw connection SQL naming a row tenant table but ignores model raw SQL" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      connection_sql = <<-CRYSTAL
        Invoice.adapter.open do |db|
          db.exec("SELECT * FROM invoices WHERE account_id = 7")
        end
        CRYSTAL
      connection_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/raw_report_job.cr", connection_sql)
      has_tenancy_diagnostic_code?(connection_diagnostics, "grant/raw-connection-sql-on-tenant-table").should be_true

      model_raw_sql = <<-CRYSTAL
        Invoice.unscoped do
          Invoice.exec("SELECT * FROM invoices")
        end
        CRYSTAL
      model_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/raw_report_job.cr", model_raw_sql)
      has_tenancy_diagnostic_code?(model_diagnostics, "grant/raw-connection-sql-on-tenant-table").should be_false

      other_table_sql = <<-CRYSTAL
        Invoice.adapter.open do |db|
          db.exec("SELECT * FROM audit_events")
        end
        CRYSTAL
      other_table_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/raw_report_job.cr", other_table_sql)
      has_tenancy_diagnostic_code?(other_table_diagnostics, "grant/raw-connection-sql-on-tenant-table").should be_false

      default_table_model = File.read(File.join(
        Dir.current,
        "spec",
        "fixtures",
        "rule_pack_apps",
        "row_app",
        "src",
        "models",
        "ledger_entry.cr",
      ))
      analyze_tenancy_fixture_source(root, "src/models/ledger_entry.cr", default_table_model)
      default_table_sql = <<-CRYSTAL
        Grant::Connections["primary"][:writer].open do |db|
          db.scalar("SELECT COUNT(*) FROM ledger_entry")
        end
        CRYSTAL
      default_table_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/raw_report_job.cr", default_table_sql)
      has_tenancy_diagnostic_code?(default_table_diagnostics, "grant/raw-connection-sql-on-tenant-table").should be_true

      annotated_table_model = File.read(File.join(
        Dir.current,
        "spec",
        "fixtures",
        "rule_pack_apps",
        "row_app",
        "src",
        "models",
        "custom_document.cr",
      ))
      analyze_tenancy_fixture_source(root, "src/models/custom_document.cr", annotated_table_model)
      annotated_table_sql = <<-CRYSTAL
        Grant::Connections["primary"][:writer].open do |db|
          db.query("SELECT * FROM custom_documents") { }
        end
        CRYSTAL
      annotated_table_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/raw_report_job.cr", annotated_table_sql)
      has_tenancy_diagnostic_code?(annotated_table_diagnostics, "grant/raw-connection-sql-on-tenant-table").should be_true
    end
  end

  it "warns about Tenant.clear outside specs and allows it in specs" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")

      app_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/reset_tenant_job.cr",
        "Grant::Tenant.clear\n",
      )
      has_tenancy_diagnostic_code?(app_diagnostics, "grant/tenant-clear-in-app-code").should be_true

      spec_diagnostics = analyze_tenancy_fixture_source(
        root,
        "spec/reset_tenant_spec.cr",
        "Grant::Tenant.clear\n",
      )
      has_tenancy_diagnostic_code?(spec_diagnostics, "grant/tenant-clear-in-app-code").should be_false

      other_clear = analyze_tenancy_fixture_source(root, "src/jobs/reset_tenant_job.cr", "Grant::SchemaTenant.clear\n")
      has_tenancy_diagnostic_code?(other_clear, "grant/tenant-clear-in-app-code").should be_false
    end
  end

  it "warns about schema queries outside a tenant block and skips excluded models" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "schema_app")

      unsafe_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/rebuild_invoice_job.cr", "Invoice.all\n")
      has_tenancy_diagnostic_code?(unsafe_diagnostics, "grant/schema-query-outside-tenant").should be_true

      scoped_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/jobs/rebuild_invoice_job.cr",
        "Grant::SchemaTenant.with(\"acme\") { Invoice.all }\n",
      )
      has_tenancy_diagnostic_code?(scoped_diagnostics, "grant/schema-query-outside-tenant").should be_false

      excluded_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/rebuild_invoice_job.cr", "Country.all\n")
      has_tenancy_diagnostic_code?(excluded_diagnostics, "grant/schema-query-outside-tenant").should be_false

      request_diagnostics = analyze_tenancy_fixture_source(
        root,
        "src/controllers/invoices_controller.cr",
        "Invoice.all\n",
      )
      has_tenancy_diagnostic_code?(request_diagnostics, "grant/schema-query-outside-tenant").should be_false
    end
  end

  it "detects schema mode from schema_tenant_excluded without requiring a with call" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "schema_app")
      File.delete(File.join(root, "config", "tenant_scope.cr"))

      diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/rebuild_invoice_job.cr", "Invoice.all\n")

      has_tenancy_diagnostic_code?(diagnostics, "grant/schema-query-outside-tenant").should be_true
    end
  end

  it "warns when both source-detected modes appear and leaves either mode alone" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "mixed_app")

      mixed_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/check_tenant_job.cr", "Invoice.all\n")
      has_tenancy_diagnostic_code?(mixed_diagnostics, "grant/tenancy-modes-mixed").should be_true
      mixed_diagnostics.any? do |diagnostic|
        diagnostic.code == "grant/tenancy-modes-mixed" && diagnostic.message.includes?("docs/schema_tenancy.md")
      end.should be_true

      install_tenancy_fixture_app(root, "row_app")
      row_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/check_tenant_job.cr", "Invoice.all\n")
      has_tenancy_diagnostic_code?(row_diagnostics, "grant/tenancy-modes-mixed").should be_false

      install_tenancy_fixture_app(root, "schema_app")
      schema_diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/check_tenant_job.cr", "Invoice.all\n")
      has_tenancy_diagnostic_code?(schema_diagnostics, "grant/tenancy-modes-mixed").should be_false
    end
  end

  it "ignores tenancy keys in shard.yml and reports no diagnostics for an app with no tenancy" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "no_tenancy_app")
      File.write(
        File.join(root, "shard.yml"),
        "name: no_tenancy_app\nversion: 0.1.0\ngrant:\n  tenancy: row\n",
      )
      Dir.mkdir_p(File.join(root, "spec"))
      File.write(File.join(root, "spec", "fake_tenancy.cr"), "Grant::SchemaTenant.with(\"spec\") { nil }\n")
      Dir.mkdir_p(File.join(root, "lib", "other"))
      File.write(File.join(root, "lib", "other", "fake_tenancy.cr"), "Grant::SchemaTenant.with(\"lib\") { nil }\n")
      File.write(
        File.join(root, "src", "models", "commented_macro.cr"),
        "# multitenant :account_id\nMESSAGE = \"schema_tenant_excluded\"\nclass Invoice\n  def configure\n    multitenant :account_id\n  end\nend\n",
      )

      diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/clean_job.cr", "Grant::Tenant.clear\nInvoice.all\n")

      diagnostics.should be_empty
      File.read(File.join(root, "shard.yml")).should contain("grant:")
    end
  end

  it "skips malformed Crystal files without crashing or inventing another mode" do
    with_tempdir do |root|
      install_tenancy_fixture_app(root, "row_app")
      Dir.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "config", "broken.cr"), "Grant::SchemaTenant.with(\"broken\") do\n")

      diagnostics = analyze_tenancy_fixture_source(root, "src/jobs/clean_job.cr", "Invoice.all\n")

      diagnostics.should be_empty
    end
  end
end
