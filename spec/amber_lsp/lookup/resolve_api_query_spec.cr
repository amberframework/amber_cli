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
    direct_result.list_of_methods.all? { |method| method.method_kind == "extended_class" }.should be_true
    ancestor_result.list_of_methods.size.should eq(2)
    ancestor_result.list_of_methods.all? { |method| method.owner == "FixtureAPI::QueryMethods" }.should be_true
    ancestor_result.list_of_methods.all? { |method| method.method_kind == "extended_class" }.should be_true
  end

  it "matches generic extension owners by their base name" do
    result = resolve_fixture_query("FixtureAPI::Team.build")

    result.list_of_methods.size.should eq(1)
    result.list_of_methods.first.owner.should eq("Grant::Query::Builder(Model)")
  end

  it "resolves self and nilable return types against the queried receiver" do
    result = resolve_return_type_fixture_query("FixtureTypes::Post.find")

    entry = result.list_of_methods.first
    entry.declared_return_type.should eq("self?")
    entry.resolved_return_type.should eq("FixtureTypes::Post | Nil")
    entry.lookup_signature.should eq(
      "FixtureTypes::ClassMethods.find(id : Int64) : FixtureTypes::Post | Nil (declared: self?) (class method via extend)",
    )
  end

  it "parses generic receivers and binds each owner type parameter" do
    builder_result = resolve_return_type_fixture_query("Grant::Query::Builder(Post)#first")
    builder_first = builder_result.list_of_methods.find { |method| method.args_string == "()" }
    builder_first_entry = builder_first || raise "Expected the no-argument first overload"
    builder_first_entry.resolved_return_type.should eq("Post | Nil")

    bare_builder_result = resolve_return_type_fixture_query("Grant::Query::Builder#first")
    bare_first = bare_builder_result.list_of_methods.find { |method| method.args_string == "()" }
    bare_first_entry = bare_first || raise "Expected the bare generic first overload"
    bare_first_entry.resolved_return_type.should eq("Model | Nil")

    lock_result = resolve_return_type_fixture_query("Grant::Query::Builder(Post)#lock")
    lock_result.list_of_methods.first.resolved_return_type.should eq("Grant::Query::Builder(Post)")

    collection_result = resolve_return_type_fixture_query("Grant::AssociationCollection(User, Post)#target")
    collection_result.list_of_methods.first.resolved_return_type.should eq("Post | Nil")

    owner_result = resolve_return_type_fixture_query("Grant::AssociationCollection(User, Post)#owner")
    owner_result.list_of_methods.first.resolved_return_type.should eq("User")

    generic_collection_result = resolve_return_type_fixture_query("Grant::Collection(Post)#first")
    generic_collection_result.list_of_methods.first.resolved_return_type.should eq("Post | Nil")

    loaded_result = resolve_return_type_fixture_query("Grant::LoadedAssociationCollection(User, Post)#clear")
    loaded_result.list_of_methods.first.resolved_return_type.should eq(
      "Grant::LoadedAssociationCollection(User, Post)",
    )

    nested_loaded_result = resolve_return_type_fixture_query(
      "Grant::LoadedAssociationCollection(User, Grant::Query::Builder(Post))#target",
    )
    nested_loaded_result.list_of_methods.first.resolved_return_type.should eq(
      "Grant::Query::Builder(Post) | Nil",
    )
  end

  it "searches generic included modules on a type and its ancestors" do
    direct_result = resolve_included_module_fixture_query("Grant::Collection(Post)#to_a")
    target_result = resolve_included_module_fixture_query("Grant::AssociationCollection(User, Post)#to_a")
    ancestor_result = resolve_included_module_fixture_query("Grant::AncestorCollection(Post)#to_a")

    direct_result.list_of_methods.size.should eq(1)
    direct_result.list_of_methods.first.owner.should eq("Enumerable(T)")
    direct_result.list_of_methods.first.resolved_return_type.should eq("Array(Post)")
    target_result.list_of_methods.first.resolved_return_type.should eq("Array(Post)")
    ancestor_result.list_of_methods.size.should eq(1)
    ancestor_result.list_of_methods.first.owner.should eq("Enumerable(T)")
    ancestor_result.list_of_methods.first.resolved_return_type.should eq("Array(Post)")
  end

  it "resolves each overload from that row's declared return type" do
    resolution = resolve_return_type_fixture_query("Grant::Query::Builder(Post)#first")
    entries = AmberLSP::Lookup::ResolveReturnTypesForAPIIndexMethods.new(
      resolution.list_of_methods,
      "Grant::Query::Builder(Post)",
    ).perform

    entries.map(&.lookup_signature).should eq([
      "Grant::Query::Builder(Model)#first() : Post | Nil (declared: Model | ::Nil)",
      "Grant::Query::Builder(Model)#first(n : Int32) : Array(Post) (declared: Array(Model))",
    ])
  end

  it "keeps a blank documentation return type unknown" do
    result = resolve_return_type_fixture_query("Grant::Query::Builder(Post)#untyped")
    entry = result.list_of_methods.first

    entry.declared_return_type.should eq("unknown")
    entry.resolved_return_type.should eq("unknown")
    entry.lookup_signature.should contain(": unknown")
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

private def resolve_return_type_fixture_query(query : String) : AmberLSP::Lookup::APIResolution
  fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_return_types.json")
  layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
    File.read(fixture_path),
    "/project",
    "project",
    "fixture_return_types",
    "fixture-key",
    [] of String,
  ).perform
  AmberLSP::Lookup::ResolveAPIQuery.new(query, [layer]).perform
end

private def resolve_included_module_fixture_query(query : String) : AmberLSP::Lookup::APIResolution
  fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_included_modules.json")
  layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
    File.read(fixture_path),
    "/project",
    "project",
    "fixture_included_modules",
    "fixture-key",
    [] of String,
  ).perform
  AmberLSP::Lookup::ResolveAPIQuery.new(query, [layer]).perform
end
