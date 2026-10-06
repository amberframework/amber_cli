require "../spec_helper"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"
require "../../../src/amber_lsp/lookup/resolve_api_query"

describe "AmberLSP::Lookup::ResolveAPIQuery#perform" do
  it "resolves a type's own class method before its ancestor method" do
    result = resolve_fixture_query("FixtureAPI::User.count")

    result.resolution_kind.should eq("class_method")
    result.list_of_methods.size.should eq(1)
    result.list_of_methods.first.owner.should eq("FixtureAPI::User")
    result.list_of_methods.first.return_type.should eq("Int32")
  end

  it "resolves class methods and instance methods through ancestors" do
    class_result = resolve_fixture_query("FixtureAPI::Team.count")
    instance_result = resolve_fixture_query("FixtureAPI::Team#created_at")

    class_result.list_of_methods.first.owner.should eq("Grant::Base")
    class_result.list_of_methods.first.return_type.should eq("Int64")
    instance_result.list_of_methods.first.owner.should eq("Grant::Base")
    instance_result.list_of_methods.first.name.should eq("created_at")
  end

  it "resolves methods extended directly on a type and on its ancestor" do
    direct_result = resolve_fixture_query("FixtureAPI::User.where")
    ancestor_result = resolve_fixture_query("FixtureAPI::Team.where")

    direct_result.resolution_kind.should eq("class_method")
    direct_result.list_of_methods.size.should eq(2)
    direct_result.list_of_methods.all? { |method| method.owner == "FixtureAPI::QueryMethods" }.should be_true
    ancestor_result.list_of_methods.size.should eq(2)
    ancestor_result.list_of_methods.all? { |method| method.owner == "FixtureAPI::QueryMethods" }.should be_true
  end

  it "matches generic extension owners by their base name" do
    result = resolve_fixture_query("FixtureAPI::Team.build")

    result.list_of_methods.size.should eq(1)
    result.list_of_methods.first.owner.should eq("Grant::Query::Builder(Model)")
  end

  it "returns a type summary for a type-only query, including a generic base-name match" do
    result = resolve_fixture_query("FixtureAPI::Team")
    generic_result = resolve_fixture_query("Grant::Query::Builder")

    result.resolution_kind.should eq("type")
    result.type_summary.should_not be_nil
    result.type_summary.not_nil!.name.should eq("FixtureAPI::Team")
    generic_result.resolution_kind.should eq("type")
    generic_result.type_summary.not_nil!.name.should eq("Grant::Query::Builder(Model)")
  end

  it "returns bare method candidates from all owners" do
    result = resolve_fixture_query("where")

    result.resolution_kind.should eq("bare_method")
    result.list_of_methods.size.should eq(2)
    result.list_of_methods.all? { |method| method.owner == "FixtureAPI::QueryMethods" }.should be_true
  end

  it "returns unknown when no type or method matches" do
    result = resolve_fixture_query("Post.find_by_sql")

    result.resolution_kind.should eq("unknown")
    result.list_of_methods.should be_empty
    result.type_summary.should be_nil
  end
end

private def resolve_fixture_query(query : String) : AmberLSP::Lookup::APIResolution
  fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
  layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
    File.read(fixture_path),
    "/project",
    "project",
    "fixture_api",
    "fixture-key",
    [] of String,
  ).perform
  AmberLSP::Lookup::ResolveAPIQuery.new(query, [layer]).perform
end
