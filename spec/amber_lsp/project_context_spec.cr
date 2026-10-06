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

    it "detects every Amber V2 stack shard name and the Amber CLI name" do
      stack_shard_names = ["amber", "amber_router", "grant", "gemma", "asset_pipeline", "micrate", "quartz_mailer", "amber_cli"]

      stack_shard_names.each do |shard_name|
        with_tempdir do |dir|
          File.write(File.join(dir, "shard.yml"), "name: #{shard_name}\nversion: 0.1.0\n")

          project_context = AmberLSP::ProjectContext.detect(dir)

          project_context.stack_project?.should be_true
          project_context.amber_project?.should eq(shard_name == "amber")
        end
      end
    end

    it "detects each Amber V2 stack dependency key" do
      stack_dependency_names = ["amber", "amber_router", "grant", "gemma", "asset_pipeline", "micrate", "quartz_mailer"]

      stack_dependency_names.each do |dependency_name|
        with_tempdir do |dir|
          shard_content = <<-YAML
            name: my_app
            version: 0.1.0
            dependencies:
              #{dependency_name}:
                github: example/#{dependency_name}
          YAML
          File.write(File.join(dir, "shard.yml"), shard_content)

          project_context = AmberLSP::ProjectContext.detect(dir)

          project_context.stack_project?.should be_true
          project_context.amber_project?.should eq(dependency_name == "amber")
        end
      end
    end

    it "declines a project with no stack name or dependency" do
      with_tempdir do |dir|
        File.write(File.join(dir, "shard.yml"), "name: my_app\nversion: 0.1.0\ndependencies:\n  kemal: {}\n")

        project_context = AmberLSP::ProjectContext.detect(dir)

        project_context.stack_project?.should be_false
      end
    end

    it "returns false for invalid YAML" do
      with_tempdir do |dir|
        File.write(File.join(dir, "shard.yml"), "{{invalid yaml")

        ctx = AmberLSP::ProjectContext.detect(dir)
        ctx.amber_project?.should be_false
        ctx.failure_reason.should_not be_nil
      end
    end
  end
end
