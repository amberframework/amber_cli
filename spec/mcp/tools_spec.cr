require "./spec_helper"

# Records the arguments it was asked to run instead of launching a process, so a
# mutating tool's validation can be specced without touching the filesystem.
class RecordingCliRunner < AmberCLI::MCP::CliRunner
  getter invocations = [] of NamedTuple(args: Array(String), chdir: String)
  property outcome : AmberCLI::MCP::CliRunner::Outcome

  def initialize(@outcome = AmberCLI::MCP::CliRunner::Outcome.new(0, "done", ""))
    super(executable: "/nonexistent/amber")
  end

  def run(args : Array(String), chdir : String) : AmberCLI::MCP::CliRunner::Outcome
    @invocations << {args: args, chdir: chdir}
    @outcome
  end
end

private def arguments(pairs)
  JSON.parse(pairs.to_json).as_h
end

# Narrows a tool's structured payload, failing the example with a readable
# message rather than a nil assertion when a tool unexpectedly returns none.
private def structured_of(outcome : AmberCLI::MCP::ToolOutcome) : JSON::Any
  payload = outcome.structured
  fail("expected structured content, got none: #{outcome.text}") if payload.nil?
  payload.as(JSON::Any)
end

# :ditto:
private def annotations_of(tool : MCProtocol::Tool) : Hash(String, JSON::Any)
  meta = tool.meta
  fail("expected annotations on #{tool.name}") if meta.nil?
  meta.as(Hash(String, JSON::Any))
end

describe AmberCLI::MCP::Tools::AmberVersionTool do
  it "reports the CLI version and the protocol revisions it speaks" do
    outcome = AmberCLI::MCP::Tools::AmberVersionTool.new.call({} of String => JSON::Any)

    outcome.error?.should be_false
    outcome.text.should contain(AmberCLI::VERSION)
    structured = structured_of(outcome)
    structured["cliVersion"].as_s.should eq(AmberCLI::VERSION)
    structured["supportedProtocolVersions"].as_a.map(&.as_s).should contain("2026-07-28")
  end
end

describe AmberCLI::MCP::Tools::ProjectInfoTool do
  it "identifies a scaffolded application and reports its configuration" do
    with_fixture_app do |app|
      outcome = AmberCLI::MCP::Tools::ProjectInfoTool.new.call(arguments({"path" => app}))

      outcome.error?.should be_false
      structured = structured_of(outcome)
      structured["amberApplication"].as_bool.should be_true
      structured["name"].as_s.should eq("fixture_app")
      structured["databaseAdapter"].as_s.should eq("sqlite")
      structured["templateLanguage"].as_s.should eq("ecr")
      structured["amberDependency"].as_s.should eq("2.0.0-beta.2")
      structured["files"]["configRoutes"].as_bool.should be_true
    end
  end

  it "reports a plain directory as not an Amber application" do
    with_mcp_tempdir do |dir|
      outcome = AmberCLI::MCP::Tools::ProjectInfoTool.new.call(arguments({"path" => dir}))

      outcome.error?.should be_false
      structured_of(outcome)["amberApplication"].as_bool.should be_false
    end
  end

  it "fails a relative path rather than resolving it against the server's cwd" do
    outcome = AmberCLI::MCP::Tools::ProjectInfoTool.new.call(arguments({"path" => "some/relative/path"}))

    outcome.error?.should be_true
    outcome.text.should contain("must be absolute")
  end

  it "fails a missing directory" do
    outcome = AmberCLI::MCP::Tools::ProjectInfoTool.new.call(arguments({"path" => "/nonexistent/amber/app"}))

    outcome.error?.should be_true
    outcome.text.should contain("No such directory")
  end
end

describe AmberCLI::MCP::Tools::ListRoutesTool do
  it "lists verb routes and expands resources for the app at the given path" do
    with_fixture_app do |app|
      outcome = AmberCLI::MCP::Tools::ListRoutesTool.new.call(arguments({"path" => app}))

      outcome.error?.should be_false
      routes = structured_of(outcome).as_a
      routes.size.should be > 0

      home = routes.find! { |route| route["uri_pattern"].as_s == "/" }
      home["verb"].as_s.should eq("get")
      home["controller"].as_s.should eq("HomeController")
      home["action"].as_s.should eq("index")
      home["pipeline"].as_s.should eq("web")

      routes.any? { |route| route["controller"].as_s == "SessionsController" }.should be_true
      # `resources` expands into the full CRUD set.
      routes.count { |route| route["controller"].as_s == "PostsController" }.should be > 4
    end
  end

  it "filters by substring" do
    with_fixture_app do |app|
      outcome = AmberCLI::MCP::Tools::ListRoutesTool.new.call(
        arguments({"path" => app, "filter" => "posts"})
      )

      routes = structured_of(outcome).as_a
      routes.should_not be_empty
      routes.all? { |route| route["controller"].as_s == "PostsController" }.should be_true
    end
  end

  it "does not depend on the process working directory" do
    with_fixture_app do |app|
      # Proves the path argument is what is used: the server's own cwd is the
      # repository, which has no config/routes.cr of its own.
      before = Dir.current
      outcome = AmberCLI::MCP::Tools::ListRoutesTool.new.call(arguments({"path" => app}))

      Dir.current.should eq(before)
      outcome.error?.should be_false
    end
  end

  it "fails when the directory holds no routes file" do
    with_mcp_tempdir do |dir|
      outcome = AmberCLI::MCP::Tools::ListRoutesTool.new.call(arguments({"path" => dir}))

      outcome.error?.should be_true
      outcome.text.should contain("No routes file")
    end
  end
end

describe AmberCLI::MCP::Tools::ListGeneratorsTool do
  it "enumerates every generator the generate command accepts" do
    outcome = AmberCLI::MCP::Tools::ListGeneratorsTool.new.call({} of String => JSON::Any)

    outcome.error?.should be_false
    structured = structured_of(outcome)
    types = structured["generators"].as_a.map(&.["type"].as_s)
    types.should eq(AmberCLI::Commands::GenerateCommand::VALID_TYPES)
    structured["fieldTypes"].as_a.map(&.as_s).should contain("string")

    scaffold = structured["generators"].as_a.find! { |generator| generator["type"].as_s == "scaffold" }
    scaffold["preview"].as_bool.should be_true
  end
end

describe AmberCLI::MCP::Tools::SearchDocsTool do
  it "finds a term in the bundled documentation" do
    outcome = AmberCLI::MCP::Tools::SearchDocsTool.new.call(arguments({"query" => "amber"}))

    outcome.error?.should be_false
    matches = structured_of(outcome)["matches"].as_a
    matches.should_not be_empty
    matches.first["document"].as_s.should_not be_empty
    matches.first["lineNumber"].as_i.should be > 0
  end

  it "reports no matches without failing" do
    outcome = AmberCLI::MCP::Tools::SearchDocsTool.new.call(
      arguments({"query" => "zzz-no-such-term-zzz"})
    )

    outcome.error?.should be_false
    structured_of(outcome)["matches"].as_a.should be_empty
  end

  it "rejects a blank query" do
    outcome = AmberCLI::MCP::Tools::SearchDocsTool.new.call(arguments({"query" => "  "}))
    outcome.error?.should be_true
  end
end

describe AmberCLI::MCP::Tools::ReadDocTool do
  it "lists the corpus when called with no id" do
    outcome = AmberCLI::MCP::Tools::ReadDocTool.new.call({} of String => JSON::Any)

    outcome.error?.should be_false
    structured_of(outcome).as_a.map(&.["id"].as_s).should contain("README.md")
  end

  it "returns a document's full text" do
    outcome = AmberCLI::MCP::Tools::ReadDocTool.new.call(arguments({"id" => "README.md"}))

    outcome.error?.should be_false
    outcome.text.should contain("Amber")
    structured_of(outcome)["id"].as_s.should eq("README.md")
  end

  it "fails an unknown id" do
    outcome = AmberCLI::MCP::Tools::ReadDocTool.new.call(arguments({"id" => "docs/nope.md"}))

    outcome.error?.should be_true
    outcome.text.should contain("Unknown document")
  end
end

describe AmberCLI::MCP::Tools::CreateNewAppTool do
  it "is advertised as mutating" do
    AmberCLI::MCP::Tools::CreateNewAppTool.new.mutating?.should be_true
  end

  it "refuses a target directory that already exists" do
    with_mcp_tempdir do |dir|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(arguments({"path" => dir}))

      outcome.error?.should be_true
      outcome.text.should contain("already exists")
      runner.invocations.should be_empty
    end
  end

  it "refuses a target file that already exists" do
    with_mcp_tempdir do |dir|
      target = File.join(dir, "taken")
      File.write(target, "occupied")

      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(arguments({"path" => target}))

      outcome.error?.should be_true
      outcome.text.should contain("already exists")
      runner.invocations.should be_empty
    end
  end

  it "refuses a relative path" do
    runner = RecordingCliRunner.new
    outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(arguments({"path" => "my_app"}))

    outcome.error?.should be_true
    outcome.text.should contain("must be absolute")
    runner.invocations.should be_empty
  end

  it "refuses a parent directory that does not exist" do
    runner = RecordingCliRunner.new
    outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(
      arguments({"path" => "/nonexistent/parent/my_app"})
    )

    outcome.error?.should be_true
    outcome.text.should contain("Parent directory does not exist")
    runner.invocations.should be_empty
  end

  it "refuses an unknown database" do
    with_mcp_tempdir do |dir|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(
        arguments({"path" => File.join(dir, "app"), "database" => "oracle"})
      )

      outcome.error?.should be_true
      outcome.text.should contain("Invalid `database`")
      runner.invocations.should be_empty
    end
  end

  it "runs the CLI non-interactively and without dependency installation by default" do
    with_mcp_tempdir do |dir|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(
        arguments({"path" => File.join(dir, "my_app"), "database" => "sqlite"})
      )

      outcome.error?.should be_false
      runner.invocations.size.should eq(1)
      invocation = runner.invocations.first
      invocation[:args].should eq(["new", "my_app", "--assume-yes", "--database=sqlite", "--no-deps"])
      invocation[:chdir].should eq(dir)
    end
  end

  it "reports a failing child process as a tool failure rather than raising" do
    with_mcp_tempdir do |dir|
      runner = RecordingCliRunner.new(
        AmberCLI::MCP::CliRunner::Outcome.new(1, "", "boom")
      )
      outcome = AmberCLI::MCP::Tools::CreateNewAppTool.new(runner).call(
        arguments({"path" => File.join(dir, "my_app")})
      )

      outcome.error?.should be_true
      outcome.text.should contain("exit code 1")
      outcome.text.should contain("boom")
    end
  end
end

describe AmberCLI::MCP::Tools::GenerateComponentTool do
  it "is advertised as mutating" do
    AmberCLI::MCP::Tools::GenerateComponentTool.new.mutating?.should be_true
  end

  it "runs the generator in the application directory" do
    with_fixture_app do |app|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::GenerateComponentTool.new(runner).call(
        arguments({"path" => app, "type" => "model", "name" => "User", "fields" => ["name:string"]})
      )

      outcome.error?.should be_false
      invocation = runner.invocations.first
      invocation[:args].should eq(["generate", "model", "User", "name:string"])
      invocation[:chdir].should eq(File.expand_path(app))
    end
  end

  it "refuses to generate into a directory that is not an Amber application" do
    with_mcp_tempdir do |dir|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::GenerateComponentTool.new(runner).call(
        arguments({"path" => dir, "type" => "model", "name" => "User"})
      )

      outcome.error?.should be_true
      outcome.text.should contain("does not look like an Amber application")
      runner.invocations.should be_empty
    end
  end

  it "refuses an unknown generator" do
    with_fixture_app do |app|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::GenerateComponentTool.new(runner).call(
        arguments({"path" => app, "type" => "widget", "name" => "User"})
      )

      outcome.error?.should be_true
      outcome.text.should contain("Unknown generator")
      runner.invocations.should be_empty
    end
  end

  it "refuses a name that is not a single token" do
    with_fixture_app do |app|
      runner = RecordingCliRunner.new
      outcome = AmberCLI::MCP::Tools::GenerateComponentTool.new(runner).call(
        arguments({"path" => app, "type" => "model", "name" => "User Profile"})
      )

      outcome.error?.should be_true
      runner.invocations.should be_empty
    end
  end
end

describe AmberCLI::MCP::ToolRegistry do
  it "advertises read-only and destructive hints so a host can gate the writers" do
    registry = AmberCLI::MCP::ToolRegistry.default

    definitions = registry.definitions.index_by(&.name)
    read_only = annotations_of(definitions["list_routes"])["annotations"]
    read_only["readOnlyHint"].as_bool.should be_true
    read_only["destructiveHint"].as_bool.should be_false

    mutating = annotations_of(definitions["create_new_app"])["annotations"]
    mutating["readOnlyHint"].as_bool.should be_false
    mutating["destructiveHint"].as_bool.should be_true
  end

  it "requires an explicit path on every application-scoped tool" do
    registry = AmberCLI::MCP::ToolRegistry.default

    ["project_info", "list_routes", "create_new_app", "generate_component"].each do |name|
      tool = registry[name]?.as(AmberCLI::MCP::BaseTool)
      tool.input_schema.required.as(Array(String)).should contain("path")
    end
  end
end
