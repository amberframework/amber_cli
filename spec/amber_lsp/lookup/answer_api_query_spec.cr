require "../spec_helper"
require "../../../src/amber_lsp/lookup/answer_api_query"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"
require "../../../src/amber_lsp/lookup/resolve_api_query"

describe "AmberLSP::Lookup::AnswerAPIQuery#perform" do
  it "returns found with fresh source provenance for an indexed method" do
    answer = build_fixture_answer("FixtureAPI::User#id", "fresh")

    answer.status.should eq("found")
    answer.freshness.should eq("fresh")
    answer.list_of_entries.first.source_layer.should eq("fixture_api")
    answer.list_of_layers.first.layer_name.should eq("fixture_api")
  end

  it "returns candidates for a bare method query" do
    answer = build_fixture_answer("where", "fresh")

    answer.status.should eq("candidates")
    answer.list_of_entries.size.should eq(2)
  end

  it "returns unknown with fresh freshness without claiming absence" do
    answer = build_fixture_answer("Post.find_by_sql", "fresh")
    json = answer.to_json

    answer.status.should eq("unknown")
    answer.freshness.should eq("fresh")
    json.should_not contain("absent")
  end

  it "preserves stale freshness when it answers from a previous layer" do
    answer = build_fixture_answer("FixtureAPI::User#id", "stale")

    answer.status.should eq("found")
    answer.freshness.should eq("stale")
    answer.list_of_entries.first.source_layer.should eq("fixture_api")
  end

  it "returns unavailable freshness when any required layer is unavailable" do
    answer = build_fixture_answer("FixtureAPI::User#id", "fresh", missing_library: true)

    answer.status.should eq("found")
    answer.freshness.should eq("unavailable")
    answer.list_of_layers.map(&.freshness).should contain("unavailable")
  end

  it "keeps unknown unknown when a stale index has no matching method" do
    answer = build_fixture_answer("Post.find_by_sql", "stale")

    answer.status.should eq("unknown")
    answer.freshness.should eq("stale")
  end

  it "marks an unknown answer unavailable if a required library layer is missing" do
    answer = build_fixture_answer("Post.find_by_sql", "fresh", missing_library: true)

    answer.status.should eq("unknown")
    answer.freshness.should eq("unavailable")
  end
end

private def build_fixture_answer(
  query : String,
  freshness : String,
  missing_library : Bool = false,
) : AmberLSP::Lookup::LookupAnswer
  fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
  layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
    File.read(fixture_path),
    "/project",
    "project",
    "fixture_api",
    "fixture-key",
    [] of String,
  ).perform
  list_of_layers = [AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, freshness)]
  if missing_library
    list_of_layers << AmberLSP::Lookup::CachedAPIIndexLayer.new(
      nil,
      "unavailable",
      "locked shard is missing",
      "library",
      "grant",
      "",
    )
  end

  resolution = AmberLSP::Lookup::ResolveAPIQuery.new(query, [layer]).perform
  AmberLSP::Lookup::AnswerAPIQuery.new(query, resolution, list_of_layers).perform
end
