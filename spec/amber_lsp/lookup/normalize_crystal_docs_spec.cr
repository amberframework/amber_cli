require "../spec_helper"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"

describe "AmberLSP::Lookup::NormalizeCrystalDocs#perform" do
  it "normalizes nested types, method overloads, module relations, and source locations" do
    fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
    normalizer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
      File.read(fixture_path),
      "/project",
      "project",
      "project",
      "project-key",
      [] of String,
    )

    layer = normalizer.perform
    user = layer.list_of_types.find { |type| type.name == "FixtureAPI::User" }
    user.should_not be_nil

    user = user.not_nil!
    user.kind.should eq("class")
    user.list_of_ancestor_names.should eq(["Grant::Base"])
    user.list_of_included_module_names.should eq(["FixtureAPI::Timestamped"])
    user.list_of_extended_module_names.should eq(["FixtureAPI::QueryMethods"])
    user.location_path.should eq("/project/src/models/user.cr")
    user.location_line.should eq(3)

    id_method = user.list_of_instance_methods.first
    id_method.owner.should eq("FixtureAPI::User")
    id_method.name.should eq("id")
    id_method.args_string.should eq("()")
    id_method.return_type.should eq("Int64 | ::Nil")
    id_method.doc_line.should eq("The user's primary key.")
    id_method.source_path.should eq("/project/src/models/user.cr")
    id_method.source_line.should eq(12)
    id_method.source_layer.should eq("project")
    id_method.abstract?.should be_false
    id_method.macro?.should be_false

    token_macro = user.list_of_macros.first
    token_macro.name.should eq("has_token")
    token_macro.macro?.should be_true

    query_methods = layer.list_of_types.find { |type| type.name == "FixtureAPI::QueryMethods" }
    query_methods.should_not be_nil
    where_overloads = query_methods.not_nil!.list_of_instance_methods.select { |method| method.name == "where" }
    where_overloads.size.should eq(2)
    where_overloads.map(&.abstract?).should eq([false, true])
  end
end
