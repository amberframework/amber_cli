require "spec"
require "json"
require "file_utils"
require "../../src/amber_cli/fsdd_docs/version_ramp"

private def with_tempdir(&)
  dir = File.join(Dir.tempdir, "fsdd_ramp_test_#{Random::Secure.hex(6)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

# Minimal Crystal docs JSON with one type and one method.
private def docs_json_for(type_name : String, method_name : String) : String
  <<-JSON
    {
      "repository_name": "T","body": "",
      "program": {
        "types": [{
          "name": "#{type_name}",
          "full_name": "#{type_name}",
          "kind": "class",
          "summary": null,
          "doc": null,
          "locations": [],
          "instance_methods": [{
            "name": "#{method_name}",
            "args_string": "()",
            "doc": null,
            "summary": null,
            "location": null,
            "def": { "name": "#{method_name}", "args": [], "return_type": "Nil", "visibility": "Public", "body": "" }
          }],
          "class_methods": [],
          "types": []
        }]
      }
    }
    JSON
end

describe AmberCLI::FSDDDocs::VersionRamp do
  describe ".empty" do
    it "returns a VersionRamp with no versions and no entries" do
      ramp = AmberCLI::FSDDDocs::VersionRamp.empty
      ramp.versions.should be_empty
      ramp.entries.should be_empty
    end

    it "returns '' for ramp_symbol on empty ramp" do
      ramp = AmberCLI::FSDDDocs::VersionRamp.empty
      ramp.ramp_symbol("SomeType", "1.0.0").should eq("")
    end

    it "returns nil for ramp_for on empty ramp" do
      ramp = AmberCLI::FSDDDocs::VersionRamp.empty
      ramp.ramp_for("SomeType").should be_nil
    end
  end

  describe ".load" do
    it "returns empty ramp when versions.json is absent" do
      with_tempdir do |dir|
        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.versions.should be_empty
      end
    end

    it "loads versions from versions.json" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))
        # No json sub-dirs, so entries will be empty but versions loaded
        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.versions.should eq(["1.0.0", "2.0.0"])
      end
    end

    it "builds entries from per-version index.json files" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\"]))
        json_dir = File.join(dir, "json", "1.0.0")
        Dir.mkdir_p(json_dir)
        File.write(File.join(json_dir, "index.json"), docs_json_for("AuthService", "authenticate"))

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.entries.has_key?("AuthService").should be_true
        ramp.entries.has_key?("AuthService#authenticate").should be_true
      end
    end

    it "tracks the first version an entry appeared" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))

        dir_v1 = File.join(dir, "json", "1.0.0")
        Dir.mkdir_p(dir_v1)
        File.write(File.join(dir_v1, "index.json"), docs_json_for("AuthService", "authenticate"))

        dir_v2 = File.join(dir, "json", "2.0.0")
        Dir.mkdir_p(dir_v2)
        File.write(File.join(dir_v2, "index.json"), docs_json_for("AuthService", "authenticate"))

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        entry = ramp.ramp_for("AuthService")
        entry.should_not be_nil
        entry.not_nil!.first_version.should eq("1.0.0")
      end
    end
  end

  describe "#ramp_symbol" do
    it "returns ↑ when entry is new in current version" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))

        # Only in v2
        dir_v2 = File.join(dir, "json", "2.0.0")
        Dir.mkdir_p(dir_v2)
        File.write(File.join(dir_v2, "index.json"), docs_json_for("NewFeature", "go"))

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.ramp_symbol("NewFeature", "2.0.0").should eq("↑")
      end
    end

    it "returns ↓ when entry was removed in current version" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))

        # Only in v1
        dir_v1 = File.join(dir, "json", "1.0.0")
        Dir.mkdir_p(dir_v1)
        File.write(File.join(dir_v1, "index.json"), docs_json_for("OldFeature", "gone"))

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.ramp_symbol("OldFeature", "2.0.0").should eq("↓")
      end
    end

    it "returns empty string when entry is stable across versions" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))

        ["1.0.0", "2.0.0"].each do |v|
          vdir = File.join(dir, "json", v)
          Dir.mkdir_p(vdir)
          File.write(File.join(vdir, "index.json"), docs_json_for("StableType", "stable"))
        end

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.ramp_symbol("StableType", "2.0.0").should eq("")
      end
    end

    it "returns empty string when current_version is nil" do
      ramp = AmberCLI::FSDDDocs::VersionRamp.empty
      ramp.ramp_symbol("SomeType", nil).should eq("")
    end

    it "returns empty string when entry is not found" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\"]))
        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.ramp_symbol("NonExistentType", "1.0.0").should eq("")
      end
    end
  end

  describe "#first_appeared" do
    it "returns the first version as 'vX.Y.Z'" do
      with_tempdir do |dir|
        File.write(File.join(dir, "versions.json"), %([\"1.0.0\", \"2.0.0\"]))

        dir_v1 = File.join(dir, "json", "1.0.0")
        Dir.mkdir_p(dir_v1)
        File.write(File.join(dir_v1, "index.json"), docs_json_for("MyType", "method"))

        ramp = AmberCLI::FSDDDocs::VersionRamp.load(dir)
        ramp.since_label("MyType").should eq("v1.0.0")
      end
    end

    it "returns nil for unknown key" do
      ramp = AmberCLI::FSDDDocs::VersionRamp.empty
      ramp.since_label("Unknown").should be_nil
    end
  end
end
