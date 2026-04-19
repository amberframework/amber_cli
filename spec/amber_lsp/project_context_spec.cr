require "./spec_helper"

describe AmberLSP::ProjectContext do
  describe ".detect" do
    it "detects an Amber project when shard.yml has amber dependency" do
      with_tempdir do |dir|
        shard_content = <<-YAML
        name: my_app
        version: 0.1.0
        dependencies:
          amber:
            github: amberframework/amber
            version: ~> 2.0.0
        YAML

        File.write(File.join(dir, "shard.yml"), shard_content)

        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_true
        ctx.root_path.should eq(dir)
      end
    end

    it "returns false when shard.yml has no amber dependency" do
      with_tempdir do |dir|
        shard_content = <<-YAML
        name: my_app
        version: 0.1.0
        dependencies:
          kemal:
            github: kemalcr/kemal
        YAML

        File.write(File.join(dir, "shard.yml"), shard_content)

        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_false
      end
    end

    it "returns false when there is no shard.yml" do
      with_tempdir do |dir|
        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_false
      end
    end

    it "returns false when shard.yml has no dependencies section" do
      with_tempdir do |dir|
        shard_content = <<-YAML
        name: my_app
        version: 0.1.0
        YAML

        File.write(File.join(dir, "shard.yml"), shard_content)

        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_false
      end
    end

    it "returns false for invalid YAML" do
      with_tempdir do |dir|
        File.write(File.join(dir, "shard.yml"), "{{invalid yaml")

        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_false
      end
    end
  end
end
