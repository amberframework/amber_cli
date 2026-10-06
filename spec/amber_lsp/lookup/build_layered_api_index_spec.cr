require "../spec_helper"
require "../../../src/amber_lsp/lookup/build_layered_api_index"

describe "AmberLSP::Lookup::BuildLayeredAPIIndex#perform" do
  it "builds project and standard library layers, then reuses their fresh cache" do
    with_tempdir do |root|
      project_root = File.join(root, "project")
      cache_root = File.join(root, "cache")
      Dir.mkdir_p(File.join(project_root, "src"))
      Dir.mkdir_p(File.join(project_root, "lib", "tiny", "src"))
      File.write(
        File.join(project_root, "shard.yml"),
        "name: lookup_fixture\nversion: 1.0.0\ndependencies:\n  tiny:\n    github: example/tiny\ntargets:\n  app:\n    main: src/lookup_fixture.cr\n",
      )
      File.write(
        File.join(project_root, "shard.lock"),
        "version: 2.0\nshards:\n  tiny:\n    git: https://example.test/tiny.git\n    version: 1.2.3+git.commit.abcd\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "shard.yml"),
        "name: tiny\nversion: 1.2.3\n",
      )
      File.write(
        File.join(project_root, "lib", "tiny", "src", "tiny.cr"),
        "module Tiny\n  class Client\n    def ping : Bool\n      true\n    end\n  end\nend\n",
      )
      File.write(
        File.join(project_root, "src", "lookup_fixture.cr"),
        "require \"tiny\"\nclass FixtureUser\n  def id : Int64?\n    1_i64\n  end\nend\n",
      )

      builder = AmberLSP::Lookup::BuildLayeredAPIIndex.new(project_root, cache_root)
      first_build = builder.perform
      second_build = builder.perform

      project_layer = first_build.find { |cached| cached.layer.try(&.layer_kind) == "project" }
      library_layer = first_build.find { |cached| cached.layer.try(&.layer_kind) == "library" }
      standard_library_layer = first_build.find { |cached| cached.layer.try(&.layer_kind) == "stdlib" }
      project_layer.should_not be_nil
      library_layer.should_not be_nil
      standard_library_layer.should_not be_nil
      project_layer.not_nil!.freshness.should eq("fresh")
      library_layer.not_nil!.freshness.should eq("fresh")
      standard_library_layer.not_nil!.freshness.should eq("fresh")

      fixture_user = project_layer.not_nil!.layer.not_nil!.list_of_types.find { |type| type.name == "FixtureUser" }
      fixture_user.should_not be_nil
      fixture_user.not_nil!.list_of_instance_methods.first.return_type.should eq("Int64 | ::Nil")

      tiny_client = library_layer.not_nil!.layer.not_nil!.list_of_types.find { |type| type.name == "Tiny::Client" }
      tiny_client.should_not be_nil
      tiny_client.not_nil!.list_of_instance_methods.first.name.should eq("ping")

      standard_types = standard_library_layer.not_nil!.layer.not_nil!.list_of_types
      dir_type = standard_types.find { |type| type.name == "Dir" }
      file_type = standard_types.find { |type| type.name == "File" }
      dir_type.should_not be_nil
      file_type.should_not be_nil
      dir_type.not_nil!.list_of_class_methods.any? { |method| method.name == "mkdir_p" }.should be_true
      file_type.not_nil!.list_of_class_methods.any? { |method| method.name == "mkdir_p" }.should be_false

      second_build.size.should eq(3)
      second_build.each { |cached| cached.freshness.should eq("fresh") }
    end
  end
end
