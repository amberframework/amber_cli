require "../spec_helper"
require "../../../src/amber_lsp/lookup/index_cache"

describe "AmberLSP::Lookup::CalculateProjectLayerKey#perform" do
  it "changes when indexed source, shard metadata, or docs flags change" do
    with_tempdir do |root|
      Dir.mkdir_p(File.join(root, "src"))
      Dir.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "shard.yml"), "name: sample\nversion: 1.0.0\n")
      File.write(File.join(root, "src", "sample.cr"), "class Sample\nend\n")
      File.write(File.join(root, "config", "app.cr"), "APP_NAME = \"sample\"\n")

      original_key = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, [] of String, "Crystal 1.21.0").perform
      File.write(File.join(root, "spec.cr"), "class Unindexed\nend\n")
      key_ignoring_unindexed_file = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, [] of String, "Crystal 1.21.0").perform
      key_with_docs_flag = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, ["grant_docs"], "Crystal 1.21.0").perform

      key_ignoring_unindexed_file.should eq(original_key)
      key_with_docs_flag.should_not eq(original_key)

      File.write(File.join(root, "src", "sample.cr"), "class Sample\n  def id : Int32\n    1\n  end\nend\n")
      key_with_changed_source = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, [] of String, "Crystal 1.21.0").perform
      key_with_changed_source.should_not eq(original_key)

      File.write(File.join(root, "config", "app.cr"), "APP_NAME = \"changed\"\n")
      key_with_changed_config = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, [] of String, "Crystal 1.21.0").perform
      key_with_changed_config.should_not eq(original_key)

      File.write(File.join(root, "shard.yml"), "name: sample\nversion: 1.0.1\n")
      key_with_changed_manifest = AmberLSP::Lookup::CalculateProjectLayerKey.new(root, [] of String, "Crystal 1.21.0").perform
      key_with_changed_manifest.should_not eq(original_key)
    end
  end
end

describe "AmberLSP::Lookup::CalculateStandardLibraryLayerKey#perform" do
  it "pins the standard library layer to the compiler identity and docs flags" do
    first_key = AmberLSP::Lookup::CalculateStandardLibraryLayerKey.new("Crystal 1.21.0").perform
    changed_compiler = AmberLSP::Lookup::CalculateStandardLibraryLayerKey.new("Crystal 1.21.1").perform
    changed_flags = AmberLSP::Lookup::CalculateStandardLibraryLayerKey.new("Crystal 1.21.0", ["stdlib_docs"]).perform

    changed_compiler.should_not eq(first_key)
    changed_flags.should_not eq(first_key)
  end
end

describe "AmberLSP::Lookup::CalculateLibraryLayerKey#perform" do
  it "includes the shard identity, locked version, docs flags, and compiler version" do
    first_key = AmberLSP::Lookup::CalculateLibraryLayerKey.new("grant", "0.23.4+git.commit.abc123", ["grant_docs"], "Crystal 1.21.0").perform
    same_key = AmberLSP::Lookup::CalculateLibraryLayerKey.new("grant", "0.23.4+git.commit.abc123", ["grant_docs"], "Crystal 1.21.0").perform
    changed_version = AmberLSP::Lookup::CalculateLibraryLayerKey.new("grant", "0.23.5", ["grant_docs"], "Crystal 1.21.0").perform
    changed_flags = AmberLSP::Lookup::CalculateLibraryLayerKey.new("grant", "0.23.4+git.commit.abc123", [] of String, "Crystal 1.21.0").perform
    changed_compiler = AmberLSP::Lookup::CalculateLibraryLayerKey.new("grant", "0.23.4+git.commit.abc123", ["grant_docs"], "Crystal 1.21.1").perform

    same_key.should eq(first_key)
    changed_version.should_not eq(first_key)
    changed_flags.should_not eq(first_key)
    changed_compiler.should_not eq(first_key)
  end
end

describe "AmberLSP::Lookup::APIIndexCache#write_layer and #load_layer" do
  it "atomically stores a fresh layer, returns stale cache on a changed key, and reports unavailable without cache" do
    with_tempdir do |root|
      cache_root = File.join(root, "cache")
      project_root = File.join(root, "project")
      layer = AmberLSP::Lookup::APIIndexLayer.new(
        "project",
        "sample",
        "key-v1",
        project_root,
        [] of String,
        [] of AmberLSP::Lookup::APIIndexType,
      )
      cache = AmberLSP::Lookup::APIIndexCache.new(cache_root, project_root)

      cache.write_layer(layer)
      fresh = cache.load_layer("project", "sample", "key-v1")
      stale = cache.load_layer("project", "sample", "key-v2")
      unavailable = AmberLSP::Lookup::APIIndexCache.new(File.join(root, "empty"), project_root)
        .load_layer("project", "sample", "key-v1")

      fresh.freshness.should eq("fresh")
      fresh.layer.should_not be_nil
      fresh.layer.not_nil!.layer_key.should eq("key-v1")
      stale.freshness.should eq("stale")
      stale.layer.should_not be_nil
      stale.layer.not_nil!.layer_key.should eq("key-v1")
      unavailable.freshness.should eq("unavailable")
      unavailable.layer.should be_nil
      Dir.glob(File.join(cache_root, "**", "*.tmp-*")).should be_empty
    end
  end
end
