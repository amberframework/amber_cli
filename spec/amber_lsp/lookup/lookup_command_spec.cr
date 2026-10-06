require "../spec_helper"
require "../../../src/amber_lsp/lookup/lookup_command"

describe AmberLSP::Lookup::ExtractLookupQueryAtPosition do
  it "uses a constant receiver and preserves its method separator" do
    source = "CLIProject::User.where(name: \"Ada\")\n"
    query = AmberLSP::Lookup::ExtractLookupQueryAtPosition.new(source, 0, 22).perform

    query.should_not be_nil
    query.not_nil!.query.should eq("CLIProject::User.where")
  end

  it "uses a bare method query for a non-constant receiver" do
    source = "user.where(name: \"Ada\")\n"
    query = AmberLSP::Lookup::ExtractLookupQueryAtPosition.new(source, 0, 8).perform

    query.should_not be_nil
    query.not_nil!.query.should eq("where")
    query.not_nil!.receiver.should eq("user")
  end

  it "extracts the receiver suffix when the line has preceding text" do
    source = "# Hover target: CLIProject::User#id\n"
    query = AmberLSP::Lookup::ExtractLookupQueryAtPosition.new(source, 0, 33).perform

    query.should_not be_nil
    query.not_nil!.query.should eq("CLIProject::User#id")
  end

  it "uses UTF-16 character offsets when the line has non-ASCII text" do
    source = "😀😀😀😀 FixtureAPI::User#id\n"
    query = AmberLSP::Lookup::ExtractLookupQueryAtPosition.new(source, 0, 28).perform

    query.should_not be_nil
    query.not_nil!.query.should eq("FixtureAPI::User#id")
  end

  it "rejects positions without an identifier" do
    query = AmberLSP::Lookup::ExtractLookupQueryAtPosition.new("User.\n", 0, 5).perform

    query.should be_nil
  end
end

describe AmberLSP::Lookup::RunLookupCommand do
  it "uses exit codes for found, candidates, and unknown index answers" do
    with_lookup_cli_project do |project|
      cache_root = lookup_cli_cache_root

      found_result = run_lookup_cli(["CLIProject::User#id", "--root", project], cache_root)
      candidate_result = run_lookup_cli(["ambiguous_method", "--root", project], cache_root)
      unknown_result = run_lookup_cli(["CLIProject::User#missing_api", "--root", project], cache_root)

      found_result[0].should eq(0)
      found_result[1].should contain("amber-lsp lookup: found (")
      found_result[1].should contain("Int64 | Nil")
      found_result[1].should contain("Note [CLIProject::User#id]")
      candidate_result[0].should eq(3)
      candidate_result[1].should contain("amber-lsp lookup: candidates (")
      unknown_result[0].should eq(4)
      unknown_result[1].should contain("amber-lsp lookup: unknown (")
    end
  end

  it "formats class methods, instance methods, and extended class methods by method kind" do
    with_lookup_cli_project do |project|
      cache_root = lookup_cli_cache_root
      class_result = run_lookup_cli(["Dir.mkdir_p", "--root", project], cache_root)
      instance_result = run_lookup_cli(["CLIProject::User#id", "--root", project], cache_root)
      extended_result = run_lookup_cli(["CLIProject::User.find", "--root", project], cache_root)

      class_result[1].should contain("Dir.mkdir_p(path : Path | String, mode : Int32 = 511) : Nil")
      class_result[1].should_not contain("Dir#mkdir_p")
      instance_result[1].should contain("CLIProject::User#id() : Int64 | Nil")
      extended_result[1].should contain("CLIProject::Querying::ClassMethods.find() : String (class method via extend)")
    end
  end

  it "uses exit code 5 for a compiler-verified absent method" do
    with_lookup_cli_project do |project|
      result = run_lookup_cli(
        ["CLIProject::User#missing_api", "--root", project, "--verify"],
        lookup_cli_cache_root,
      )

      result[0].should eq(5)
      result[1].should contain("amber-lsp lookup: absent (")
      result[2].should contain("verified absent in")
    end
  end

  it "prints its usage and exit codes for --help" do
    result = run_lookup_cli(["--help"], lookup_cli_cache_root)

    result[0].should eq(0)
    result[1].should contain("Usage: amber-lsp lookup QUERY")
    result[1].should contain("Exit codes: 0 found, 3 several candidates, 4 unknown, 5 absent, 2 failed.")
    result[2].should eq("")
  end

  it "uses exit code 2 when the compiler cannot run" do
    with_lookup_cli_project do |project|
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      code = AmberLSP::Lookup::RunLookupCommand.new(
        ["CLIProject::User#missing_api", "--root", project, "--verify"],
        lookup_cli_cache_root,
        "crystal-alpha-not-installed",
        stdout,
        stderr,
      ).perform

      code.should eq(2)
      stderr.to_s.should contain("amber-lsp lookup failed")
    end
  end

  it "emits the answer fields and verification duration as JSON" do
    with_lookup_cli_project do |project|
      result = run_lookup_cli(
        ["CLIProject::User#id", "--root", project, "--json", "--verify"],
        lookup_cli_cache_root,
      )
      json = JSON.parse(result[1])

      result[0].should eq(0)
      json["status"].as_s.should eq("found")
      json["freshness"].as_s.should eq("fresh")
      json["entries"].as_a.first["name"].as_s.should eq("id")
      json["entries"].as_a.first["declared_return_type"].as_s.should eq("Int64 | ::Nil")
      json["entries"].as_a.first["resolved_return_type"].as_s.should eq("Int64 | Nil")
      json["entries"].as_a.first["verified_return_type"].as_s.should eq("Int64 | Nil")
      json["verified_return_type"].as_s.should eq("Int64 | Nil")
      json["verification_status"].as_s.should eq("present")
      json["verification_elapsed_milliseconds"].as_i.should be >= 0
      json["card_notes"].as_a.size.should eq(1)

      text_result = run_lookup_cli(
        ["CLIProject::User#id", "--root", project, "--verify"],
        lookup_cli_cache_root,
      )
      text_result[0].should eq(0)
      text_result[1].should contain("verified type: Int64 | Nil")
    end
  end

  it "turns --at file positions into a constant method query" do
    with_lookup_cli_project do |project|
      file_path = File.join(project, "src", "hover.cr")
      source = "CLIProject::User#id\n"
      File.write(file_path, source)
      at_location = "#{file_path}:1:19"
      result = run_lookup_cli(["--at", at_location, "--root", project], lookup_cli_cache_root)

      result[0].should eq(0)
      result[1].should contain("amber-lsp lookup: found (")
      result[1].should contain("id")
    end
  end
end

private def run_lookup_cli(arguments : Array(String), cache_root : String) : Tuple(Int32, String, String)
  stdout = IO::Memory.new
  stderr = IO::Memory.new
  code = AmberLSP::Lookup::RunLookupCommand.new(arguments, cache_root, "crystal-alpha", stdout, stderr).perform
  {code, stdout.to_s, stderr.to_s}
end

private def lookup_cli_cache_root : String
  File.join(Dir.current, ".luna", "lookup-cli-test-cache")
end

private def with_lookup_cli_project(&)
  with_tempdir do |project|
    source_path = File.join(project, "src", "cli_lookup_fixture.cr")
    Dir.mkdir_p(File.dirname(source_path))
    Dir.mkdir_p(File.join(project, ".amber-lsp", "api"))
    File.write(File.join(project, "shard.yml"), <<-YAML)
      name: cli_lookup_fixture
      version: 0.1.0
      targets:
        cli_lookup_fixture:
          main: src/cli_lookup_fixture.cr
    YAML
    File.write(source_path, <<-CRYSTAL)
      module CLIProject
        module Querying
          module ClassMethods
            def find : String
              "found"
            end
          end
        end

        class Parent
          extend Querying::ClassMethods

          def inherited_api
          end
        end

        class User < Parent
          getter id : Int64?
        end

        class One
          def ambiguous_method
          end
        end

        class Two
          def ambiguous_method
          end
        end
      end
    CRYSTAL
    File.write(
      File.join(project, ".amber-lsp", "api", "cli_lookup_fixture.yml"),
      "card_version: 1\nlibrary: cli_lookup_fixture\napplies_to: 0.1.0\nnotes:\n  - symbol: CLIProject::User#id\n    text: The ID is a nullable persisted column.\n",
    )
    yield project
  end
end
