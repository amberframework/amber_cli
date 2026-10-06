require "../spec_helper"
require "../../../src/amber_lsp/lookup/api_cards"

describe AmberLSP::Lookup::APIVersionRequirement do
  it "matches exact, comparator, and pessimistic semantic version requirements" do
    AmberLSP::Lookup::APIVersionRequirement.new("1.2.3").matches?("1.2.3").should be_true
    AmberLSP::Lookup::APIVersionRequirement.new(">= 1.0, < 2.0.0").matches?("1.5.0").should be_true
    AmberLSP::Lookup::APIVersionRequirement.new("~> 0.3.0").matches?("0.3.9").should be_true
    AmberLSP::Lookup::APIVersionRequirement.new("~> 0.3.0").matches?("0.4.0").should be_false
  end
end

describe AmberLSP::Lookup::LoadAPICards do
  it "loads the project card and locked library cards with notes and error hints" do
    with_api_card_project do |project|
      cards = AmberLSP::Lookup::LoadAPICards.new(project).perform

      cards.list_of_errors.should be_empty
      cards.list_of_cards.map(&.card.library).should eq(["fixture_project", "example", "crystal"])
      cards.docs_flags_by_library.should eq({
        "fixture_project" => ["fixture_project_docs"],
        "example"         => ["example_docs"],
        "crystal"         => [] of String,
      })
      cards.docs_entries_by_library.should eq({
        "example" => ["src/example.cr", "src/ui.cr"],
      })
      cards.matching_notes("FixtureAPI::User#id").map(&.text).should contain(
        "The ID getter is generated from the persisted table column."
      )
      cards.matching_notes("Example::Widget#id").map(&.text).should contain(
        "This getter follows the library's primary key."
      )
      cards.matching_error_hints("undefined method 'lookup' for Example::Widget").map(&.example).should contain(
        "Example::Widget.lookup(\"widget-1\")"
      )
    end
  end

  it "applies the owner repository card against the project's own version" do
    with_api_card_project do |project|
      File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
      cards = AmberLSP::Lookup::LoadAPICards.new(project).perform

      cards.list_of_cards.map(&.card.library).should contain("fixture_project")
    end
  end

  it "ignores cards whose applies_to range does not match the locked version" do
    with_api_card_project do |project|
      File.write(File.join(project, "shard.lock"), "shards:\n  example:\n    version: 0.4.0\n")
      cards = AmberLSP::Lookup::LoadAPICards.new(project).perform

      cards.list_of_cards.map(&.card.library).should_not contain("example")
      cards.list_of_errors.should be_empty
    end
  end

  it "rejects unsupported card versions and malformed error regular expressions" do
    with_api_card_project do |project|
      card_path = File.join(project, "lib", "example", ".amber-lsp", "api", "example.yml")
      card = File.read(card_path).gsub("card_version: 1", "card_version: 2")
      File.write(card_path, card)

      cards = AmberLSP::Lookup::LoadAPICards.new(project).perform

      cards.list_of_cards.map(&.card.library).should_not contain("example")
      cards.list_of_errors.first.should contain("card_version must be 1")

      invalid_pattern_card = File.read(card_path).gsub("card_version: 2", "card_version: 1").gsub("pattern: \"undefined method 'lookup'\"", "pattern: \"[\"")
      File.write(card_path, invalid_pattern_card)
      invalid_pattern_result = AmberLSP::Lookup::LoadAPICards.new(project).perform
      invalid_pattern_result.list_of_cards.map(&.card.library).should_not contain("example")
      invalid_pattern_result.list_of_errors.first.should contain(card_path)
    end
  end

  it "substitutes numbered and named captures in matching card hints and examples" do
    with_capture_card_project do |project|
      cards = AmberLSP::Lookup::LoadAPICards.new(project).perform
      matches = cards.matching_error_hint_matches("undefined method 'lookup' for Example::Widget")

      matches.map(&.error_hint.hint).should eq([
        "Call lookup on Example::Widget.",
        "Use lookup with the widget.",
      ])
      matches.map(&.error_hint.example).should eq([
        "Example::Widget.lookup(\"widget-1\")",
        "Example::Widget.lookup(\"widget-2\")",
      ])
      matches.map(&.card_library).should eq(["fixture_project", "fixture_project"])
      matches.map(&.card_version).should eq(["1.5.0", "1.5.0"])
    end
  end

  it "loads a version-compatible installed bundled card from the real executable prefix" do
    with_bundled_card_project do |project, _executable_path, prefix|
      real_prefix = File.join(prefix, "real")
      real_bin_path = File.join(real_prefix, "bin")
      Dir.mkdir_p(real_bin_path)
      real_executable_path = File.join(real_bin_path, "amber-lsp")
      File.write(real_executable_path, "binary")
      symlink_path = File.join(prefix, "bin", "amber-lsp")
      File.delete(symlink_path)
      File.symlink(real_executable_path, symlink_path)
      installed_cards_path = File.join(real_prefix, "share", "amber_cli", "api")
      Dir.mkdir_p(installed_cards_path)
      card_path = File.join(installed_cards_path, "crystal.yml")
      File.write(card_path, bundled_test_card("installed hint", ">= 1.21.0, < 2.0.0"))

      cards = AmberLSP::Lookup::LoadAPICards.new(
        project,
        symlink_path,
        [{"crystal.yml", bundled_test_card("compiled fallback hint", ">= 1.21.0, < 2.0.0")}],
      ).perform
      loaded_card = cards.list_of_cards.find { |card| card.card.library == "crystal" }

      cards.list_of_errors.should be_empty
      loaded_card.should_not be_nil
      if loaded = loaded_card
        loaded.source_path.should eq(File.realpath(card_path))
        loaded.resolved_version.should eq(installed_crystal_version)
        loaded.origin.should eq(AmberLSP::Lookup::APICardOrigin::Bundled)
      else
        fail("expected the installed Crystal API card")
      end
      cards.matching_error_hint_matches("card conflict").map(&.error_hint.hint).should eq(["installed hint"])
    end
  end

  it "uses the compiled card when an installed card does not apply to this Crystal version" do
    with_bundled_card_project do |project, executable_path, prefix|
      installed_cards_path = File.join(prefix, "share", "amber_cli", "api")
      Dir.mkdir_p(installed_cards_path)
      File.write(
        File.join(installed_cards_path, "crystal.yml"),
        bundled_test_card("future installed hint", ">= 99.0.0"),
      )
      embedded_cards = [{"crystal.yml", bundled_test_card("compiled hint", ">= 1.21.0, < 2.0.0")}]

      cards = AmberLSP::Lookup::LoadAPICards.new(project, executable_path, embedded_cards).perform
      loaded_card = cards.list_of_cards.find { |card| card.card.library == "crystal" }

      cards.list_of_errors.should be_empty
      loaded_card.should_not be_nil
      if loaded = loaded_card
        loaded.source_path.should eq("embedded:crystal.yml")
      else
        fail("expected the compiled Crystal API card")
      end
      cards.matching_error_hint_matches("card conflict").map(&.error_hint.hint).should eq(["compiled hint"])
    end
  end

  it "gives project and library hints precedence over conflicting bundled hints" do
    with_bundled_card_project do |project, executable_path, _prefix|
      write_test_card(project, "fixture_project", "project pattern", "project hint")
      library_root = File.join(project, "lib", "example")
      Dir.mkdir_p(File.join(library_root, ".amber-lsp", "api"))
      File.write(
        File.join(library_root, ".amber-lsp", "api", "example.yml"),
        card_yaml("example", "library pattern", "library hint", ">= 0.3.0"),
      )
      File.write(
        File.join(project, "shard.lock"),
        "shards:\n  example:\n    version: 0.3.5\n",
      )
      embedded_cards = [{"crystal.yml", bundled_test_card("bundled hint", ">= 1.21.0")}]

      cards = AmberLSP::Lookup::LoadAPICards.new(project, executable_path, embedded_cards).perform

      cards.matching_error_hint_matches("project pattern").map(&.error_hint.hint).should eq(["project hint"])
      cards.matching_error_hint_matches("library pattern").map(&.error_hint.hint).should eq(["library hint"])
    end
  end
end

private def with_api_card_project(&)
  with_tempdir do |project|
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "cards")
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    FileUtils.cp_r(File.join(fixture_root, "project", ".amber-lsp"), project)
    Dir.mkdir_p(File.join(project, "lib", "example"))
    FileUtils.cp_r(File.join(fixture_root, "library", ".amber-lsp"), File.join(project, "lib", "example"))
    FileUtils.cp_r(File.join(fixture_root, "library", "src"), File.join(project, "lib", "example"))
    File.write(File.join(project, "shard.lock"), "shards:\n  example:\n    version: 0.3.5\n")
    yield project
  end
end

private def with_capture_card_project(&)
  with_tempdir do |project|
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "capture_cards")
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    FileUtils.cp_r(File.join(fixture_root, ".amber-lsp"), project)
    yield project
  end
end

private def with_bundled_card_project(&)
  with_tempdir do |directory|
    project = File.join(directory, "project")
    prefix = File.join(directory, "prefix")
    Dir.mkdir_p(project)
    Dir.mkdir_p(File.join(prefix, "bin"))
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    executable_path = File.join(prefix, "bin", "amber-lsp")
    File.write(executable_path, "binary")
    yield project, executable_path, prefix
  end
end

private def bundled_test_card(hint : String, requirement : String) : String
  card_yaml("crystal", "card conflict", hint, requirement)
end

private def card_yaml(library : String, pattern : String, hint : String, requirement : String = ">= 1.0.0") : String
  <<-YAML
  card_version: 1
  library: #{library}
  applies_to: "#{requirement}"
  error_hints:
    - pattern: "#{pattern}"
      hint: "#{hint}"
      example: "#{hint}"
  YAML
end

private def write_test_card(project : String, library : String, pattern : String, hint : String) : Nil
  api_path = File.join(project, ".amber-lsp", "api")
  Dir.mkdir_p(api_path)
  File.write(File.join(api_path, "#{library}.yml"), card_yaml(library, pattern, hint))
end

# The version the installed compiler reports; cards resolve against it.
private def installed_crystal_version : String
  output = IO::Memory.new
  Process.run(AmberLSP::Lookup.default_compiler_command, ["--version"], output: output)
  output.to_s[/Crystal\s+(\d+\.\d+\.\d+)/, 1]
end
