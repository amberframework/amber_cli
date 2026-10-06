require "../spec_helper"
require "../../../src/amber_lsp/lookup/index_cache"
require "../../../src/amber_lsp/lookup/merge_api_index_layers"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"
require "../../../src/amber_lsp/lookup/resolve_api_query"

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

    constructors = user.list_of_class_methods.select { |method| method.name == "new" }
    constructors.size.should eq(1)
    constructors.first.args_string.should eq("(name : String)")
    constructors.first.declared_return_type.should eq("FixtureAPI::User")
    constructors.first.resolved_return_type.should eq("FixtureAPI::User")
    constructors.first.source_path.should eq("/project/src/models/user.cr")
    constructors.first.source_line.should eq(5)
  end

  it "indexes Enumerable methods forwarded by Grant::Collection" do
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "forwarded_collection")
    fixture_path = File.join(fixture_root, "crystal_docs.json")
    layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
      File.read(fixture_path),
      fixture_root,
      "library",
      "grant",
      "grant-key",
      [] of String,
    ).perform

    collection = layer.list_of_types.find { |type| type.name == "Grant::Collection(M)" }
    if collection_type = collection
      collection_type.list_of_included_module_names.should contain("Enumerable(M)")
    else
      raise Exception.new("Expected the normalized Grant::Collection type")
    end
  end

  it "keeps library entries under their owning shard and the stdlib layer" do
    s3_layer = normalize_library_source_fixture("awscr-s3")
    signer_layer = normalize_library_source_fixture("awscr-signer")

    s3_client = s3_layer.list_of_types.find { |type| type.name == "Awscr::S3::Client" }
    signer_client = signer_layer.list_of_types.find { |type| type.name == "Awscr::S3::Client" }
    s3_client = s3_client || raise "Expected Awscr::S3::Client in the S3 layer"
    signer_client = signer_client || raise "Expected Awscr::S3::Client reopening in the signer layer"

    s3_client.list_of_instance_methods.map(&.name).should eq(["list"])
    signer_client.location_path.should eq("/fixture_app/lib/awscr-signer/src/awscr/s3/client.cr")
    signer_client.list_of_instance_methods.map(&.name).should eq(["sign"])
    s3_layer.list_of_types.map(&.name).should contain("Awscr::S3::UnusedS3Type")
    signer_layer.list_of_types.map(&.name).should contain("Awscr::Signer::Signer")
    s3_layer.list_of_types.map(&.name).should_not contain("HTTP::Headers")
    signer_layer.list_of_types.map(&.name).should_not contain("Awscr::S3::UnusedS3Type")
    signer_layer.list_of_types.map(&.name).should_not contain("HTTP::Headers")

    merged_layer = AmberLSP::Lookup::MergeAPIIndexLayers.new([s3_layer, signer_layer]).perform
    list_resolution = AmberLSP::Lookup::ResolveAPIQuery.new("Awscr::S3::Client#list", [merged_layer]).perform
    sign_resolution = AmberLSP::Lookup::ResolveAPIQuery.new("Awscr::S3::Client#sign", [merged_layer]).perform

    list_resolution.list_of_methods.first.source_layer.should eq("awscr-s3")
    sign_resolution.list_of_methods.first.source_layer.should eq("awscr-signer")
  end

  it "fails when a library docs entry has no known source root" do
    fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_unknown_library_location.json")
    standard_library_root = "/fixture_app/crystal/src"
    normalizer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
      File.read(fixture_path),
      "/fixture_app/lib/awscr-signer",
      "library",
      "awscr-signer",
      "fixture-key",
      [] of String,
      nil,
      {standard_library_root => standard_library_root},
    )

    error = expect_raises(AmberLSP::Lookup::APIIndexBuildError) { normalizer.perform }
    error_message = error.message || raise "Expected a message for the unknown source path"
    error_message.should contain("/fixture_app/untracked/private.cr")
  end
end

private def normalize_library_source_fixture(layer_name : String) : AmberLSP::Lookup::APIIndexLayer
  fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_library_source_ownership.json")
  standard_library_root = "/fixture_app/crystal/src"
  AmberLSP::Lookup::NormalizeCrystalDocs.new(
    File.read(fixture_path),
    File.join("/fixture_app/lib", layer_name),
    "library",
    layer_name,
    "#{layer_name}-fixture-key",
    [] of String,
    nil,
    {standard_library_root => standard_library_root},
  ).perform
end
