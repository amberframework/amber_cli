require "../spec_helper"
require "../../../src/amber_lsp/lookup/build_layered_api_index"

describe "AmberLSP::Lookup::BuildLayeredAPIIndex#perform" do
  it "builds project and standard library layers, then reuses their fresh cache" do
    with_tempdir do |root|
      project_root = File.join(root, "project")
      cache_root = File.join(root, "cache")
      Dir.mkdir_p(File.join(project_root, "src"))
      Dir.mkdir_p(File.join(project_root, "lib", "tiny", "src"))
      Dir.mkdir_p(File.join(project_root, "lib", "sibling", "src"))
      Dir.mkdir_p(File.join(project_root, ".amber-lsp", "api"))
      Dir.mkdir_p(File.join(project_root, "lib", "tiny", ".amber-lsp", "api"))
      File.write(
        File.join(project_root, "shard.yml"),
        "name: lookup_fixture\nversion: 1.0.0\ndependencies:\n  tiny:\n    github: example/tiny\ntargets:\n  app:\n    main: src/lookup_fixture.cr\n",
      )
      File.write(
        File.join(project_root, "shard.lock"),
        "version: 2.0\nshards:\n  sibling:\n    git: https://example.test/sibling.git\n    version: 1.0.0+git.commit.abcd\n  tiny:\n    git: https://example.test/tiny.git\n    version: 1.2.3+git.commit.abcd\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "shard.yml"),
        "name: tiny\nversion: 1.2.3\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "src", "tiny.cr"),
        "require \"sibling\"\nmodule Tiny\n  class Client\n    def ping : Bool\n      true\n    end\n\n    def sibling_token : Sibling::Token\n      Sibling::Token.new\n    end\n  end\nend\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "src", "ui.cr"),
        "module Tiny\n  module UI\n    class Label\n      def text=(new_text : String) : String\n        new_text\n      end\n    end\n  end\nend\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "src", "components.cr"),
        "module Tiny\n  class FrameworkRegistry\n  end\n\n  class Client\n    def ping : Bool\n      true\n    end\n  end\nend\n",
      )
      File.write(File.join(project_root, "lib", "tiny", "src", "broken.cr"), "module Tiny\n  class Broken\n")
      File.write(
        File.join(project_root, "lib", "sibling", "src", "sibling.cr"),
        "module Sibling\n  class Token\n  end\nend\n",
      )
      File.write(
        File.join(project_root, "src", "lookup_fixture.cr"),
        "require \"tiny\"\nclass FixtureUser\n  def id : Int64?\n    1_i64\n  end\nend\n",
      )
      File.write(
        File.join(project_root, ".amber-lsp", "api", "lookup_fixture.yml"),
        "card_version: 1\nlibrary: lookup_fixture\napplies_to: 1.0.0\ndocs_flags:\n  - fixture_docs\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", ".amber-lsp", "api", "tiny.yml"),
        "card_version: 1\nlibrary: tiny\napplies_to: '~> 1.2.0'\ndocs_flags:\n  - tiny_docs\n",
      )

      builder = AmberLSP::Lookup::BuildLayeredAPIIndex.new(project_root, cache_root)
      first_build = builder.perform
      second_build = builder.perform

      project_layer = first_build.find { |cached| cached.layer.try(&.layer_kind) == "project" }
      library_layer = first_build.find do |cached|
        cached.layer.try(&.layer_kind) == "library" && cached.layer.try(&.layer_name) == "tiny"
      end
      standard_library_layer = first_build.find { |cached| cached.layer.try(&.layer_kind) == "stdlib" }
      project_layer.should_not be_nil
      library_layer.should_not be_nil
      standard_library_layer.should_not be_nil
      project_layer.not_nil!.freshness.should eq("fresh")
      library_layer.not_nil!.freshness.should eq("fresh")
      standard_library_layer.not_nil!.freshness.should eq("fresh")
      project_layer.not_nil!.layer.not_nil!.docs_flags.should eq(["fixture_docs"])
      library_layer.not_nil!.layer.not_nil!.docs_flags.should eq(["tiny_docs"])

      fixture_user = project_layer.not_nil!.layer.not_nil!.list_of_types.find { |type| type.name == "FixtureUser" }
      fixture_user.should_not be_nil
      fixture_user.not_nil!.list_of_instance_methods.first.return_type.should eq("Int64 | ::Nil")

      tiny_client = library_layer.not_nil!.layer.not_nil!.list_of_types.find { |type| type.name == "Tiny::Client" }
      tiny_client.should_not be_nil
      tiny_client.not_nil!.list_of_instance_methods.first.name.should eq("ping")
      if client = tiny_client
        client.list_of_instance_methods.find { |method| method.name == "sibling_token" }.should_not be_nil
        client.list_of_instance_methods.count { |method| method.name == "ping" }.should eq(1)
        client.location_path.should eq(File.join(project_root, "lib", "tiny", "src", "tiny.cr"))
      end
      tiny_types = library_layer.not_nil!.layer.not_nil!.list_of_types
      tiny_types.any? { |type| type.name == "Tiny::UI::Label" }.should be_true
      tiny_types.any? { |type| type.name == "Tiny::FrameworkRegistry" }.should be_true
      failed_entries = library_layer.not_nil!.layer.not_nil!.to_json
      failed_entries.should contain("src/broken.cr")
      failed_entries.should contain("entry_failures")
      failed_entries.should contain("crystal-alpha docs failed")

      standard_types = standard_library_layer.not_nil!.layer.not_nil!.list_of_types
      dir_type = standard_types.find { |type| type.name == "Dir" }
      file_type = standard_types.find { |type| type.name == "File" }
      dir_type.should_not be_nil
      file_type.should_not be_nil
      dir_type.not_nil!.list_of_class_methods.any? { |method| method.name == "mkdir_p" }.should be_true
      file_type.not_nil!.list_of_class_methods.any? { |method| method.name == "mkdir_p" }.should be_false

      second_build.size.should eq(4)
      second_build.each { |cached| cached.freshness.should eq("fresh") }
      Dir.children(File.join(cache_root, "docs-workspaces")).should be_empty
    end
  end

  it "uses API-card docs entries instead of automatic library entries" do
    with_tempdir do |root|
      source_root = File.join(root, "src")
      Dir.mkdir_p(File.join(source_root, "nested"))
      ["tiny.cr", "ui.cr", "components.cr"].each do |filename|
        File.write(File.join(source_root, filename), "module Tiny\nend\n")
      end

      automatic_entries = AmberLSP::Lookup::ResolveAPIIndexDocsEntries.new(root, "tiny").perform
      explicit_entries = AmberLSP::Lookup::ResolveAPIIndexDocsEntries.new(
        root,
        "tiny",
        ["src/ui.cr", "src/tiny.cr"],
      ).perform

      automatic_entries.should eq(["src/tiny.cr", "src/components.cr", "src/ui.cr"])
      explicit_entries.should eq(["src/tiny.cr", "src/ui.cr"])
    end
  end
end
