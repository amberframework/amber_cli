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
      cards.list_of_cards.map(&.card.library).should eq(["fixture_project", "example"])
      cards.docs_flags_by_library.should eq({
        "fixture_project" => ["fixture_project_docs"],
        "example"         => ["example_docs"],
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
end

private def with_api_card_project(&)
  with_tempdir do |project|
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "cards")
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    FileUtils.cp_r(File.join(fixture_root, "project", ".amber-lsp"), project)
    Dir.mkdir_p(File.join(project, "lib", "example"))
    FileUtils.cp_r(File.join(fixture_root, "library", ".amber-lsp"), File.join(project, "lib", "example"))
    File.write(File.join(project, "shard.lock"), "shards:\n  example:\n    version: 0.3.5\n")
    yield project
  end
end
