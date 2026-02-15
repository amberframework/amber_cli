require "./spec_helper"

describe AmberLSP::Configuration do
  describe ".parse" do
    it "parses rule enabled/disabled settings" do
      yaml = <<-YAML
      rules:
        amber/model-naming:
          enabled: false
        amber/route-naming:
          enabled: true
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.rule_enabled?("amber/model-naming").should be_false
      config.rule_enabled?("amber/route-naming").should be_true
    end

    it "parses rule severity overrides" do
      yaml = <<-YAML
      rules:
        amber/model-naming:
          enabled: true
          severity: error
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.rule_severity("amber/model-naming", AmberLSP::Rules::Severity::Warning).should eq(AmberLSP::Rules::Severity::Error)
    end

    it "returns default severity when no override is set" do
      yaml = <<-YAML
      rules:
        amber/model-naming:
          enabled: true
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.rule_severity("amber/model-naming", AmberLSP::Rules::Severity::Warning).should eq(AmberLSP::Rules::Severity::Warning)
    end

    it "parses custom exclude patterns" do
      yaml = <<-YAML
      exclude:
        - vendor/
        - generated/
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.exclude_patterns.should eq(["vendor/", "generated/"])
    end

    it "uses default exclude patterns when none specified" do
      yaml = <<-YAML
      rules:
        amber/model-naming:
          enabled: true
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.exclude_patterns.should eq(["lib/", "tmp/", "db/migrations/"])
    end

    it "handles invalid YAML gracefully" do
      config = AmberLSP::Configuration.parse("{{invalid")
      config.rule_enabled?("any-rule").should be_true
    end
  end

  describe "#rule_enabled?" do
    it "returns true for unconfigured rules" do
      config = AmberLSP::Configuration.new
      config.rule_enabled?("unknown-rule").should be_true
    end
  end

  describe "#rule_severity" do
    it "returns default for unconfigured rules" do
      config = AmberLSP::Configuration.new
      config.rule_severity("unknown-rule", AmberLSP::Rules::Severity::Hint).should eq(AmberLSP::Rules::Severity::Hint)
    end
  end

  describe "#excluded?" do
    it "excludes files matching default patterns" do
      config = AmberLSP::Configuration.new
      config.excluded?("lib/some_shard/src/foo.cr").should be_true
      config.excluded?("tmp/cache/bar.cr").should be_true
      config.excluded?("db/migrations/001_create_users.cr").should be_true
    end

    it "does not exclude normal project files" do
      config = AmberLSP::Configuration.new
      config.excluded?("src/controllers/home_controller.cr").should be_false
      config.excluded?("src/models/user.cr").should be_false
    end
  end

  describe ".load" do
    it "loads configuration from .amber-lsp.yml in project root" do
      with_tempdir do |dir|
        yaml = <<-YAML
        rules:
          amber/model-naming:
            enabled: false
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        config = AmberLSP::Configuration.load(dir)
        config.rule_enabled?("amber/model-naming").should be_false
      end
    end

    it "returns default configuration when no config file exists" do
      with_tempdir do |dir|
        config = AmberLSP::Configuration.load(dir)
        config.rule_enabled?("any-rule").should be_true
        config.exclude_patterns.should eq(["lib/", "tmp/", "db/migrations/"])
      end
    end
  end
end
