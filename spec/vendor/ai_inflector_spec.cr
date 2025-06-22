require "../spec_helper"

describe AmberCLI::Vendor::Inflector::AITransformer do
  describe "configuration" do
    it "can be configured" do
      AmberCLI::Vendor::Inflector::AITransformer.configure do |config|
        config.enabled = true
        config.api_key = "test-key"
        config.model = "test-model"
        config.timeout = 10.seconds
      end
      
      # Note: We can't directly access config in tests, but this verifies
      # that the configuration method works without errors
    end
  end

  describe "caching" do
    it "starts with empty cache" do
      AmberCLI::Vendor::Inflector::AITransformer.clear_cache
      stats = AmberCLI::Vendor::Inflector::AITransformer.cache_stats
      stats[:size].should eq(0)
    end

    it "can clear cache" do
      AmberCLI::Vendor::Inflector::AITransformer.clear_cache
      stats = AmberCLI::Vendor::Inflector::AITransformer.cache_stats
      stats[:size].should eq(0)
    end
  end

  describe "transform_with_ai" do
    it "returns nil when disabled" do
      AmberCLI::Vendor::Inflector::AITransformer.configure do |config|
        config.enabled = false
      end
      
      result = AmberCLI::Vendor::Inflector::AITransformer.transform_with_ai("test", "plural")
      result.should be_nil
    end

    it "returns nil for empty words" do
      AmberCLI::Vendor::Inflector::AITransformer.configure do |config|
        config.enabled = true
      end
      
      result = AmberCLI::Vendor::Inflector::AITransformer.transform_with_ai("", "plural")
      result.should be_nil
    end

    it "returns nil when no API key is set" do
      AmberCLI::Vendor::Inflector::AITransformer.configure do |config|
        config.enabled = true
        config.api_key = nil
      end
      
      result = AmberCLI::Vendor::Inflector::AITransformer.transform_with_ai("test", "plural")
      result.should be_nil
    end
  end
end

describe AmberCLI::Vendor::Inflector do
  describe "AI integration" do
    it "falls back to local rules when AI is disabled" do
      # Standard local rules should still work
      AmberCLI::Vendor::Inflector.pluralize("user").should eq("users")
      AmberCLI::Vendor::Inflector.pluralize("child").should eq("children")
      AmberCLI::Vendor::Inflector.singularize("users").should eq("user")
      AmberCLI::Vendor::Inflector.singularize("children").should eq("child")
    end

    it "has convenience configuration method" do
      # This should work without errors
      AmberCLI::Vendor::Inflector.configure_ai do |ai|
        ai.configure do |config|
          config.enabled = false
        end
      end
    end
  end

  describe "AI fallback decision logic" do
    it "handles regular plurals locally" do
      # These should not trigger AI fallback (handled by local rules)
      AmberCLI::Vendor::Inflector.pluralize("cat").should eq("cats")
      AmberCLI::Vendor::Inflector.pluralize("company").should eq("companies")
      AmberCLI::Vendor::Inflector.pluralize("child").should eq("children")
    end

    it "handles uncountable words locally" do
      # These should not trigger AI fallback
      AmberCLI::Vendor::Inflector.pluralize("sheep").should eq("sheep")
      AmberCLI::Vendor::Inflector.pluralize("fish").should eq("fish")
      AmberCLI::Vendor::Inflector.pluralize("information").should eq("information")
    end

    it "preserves irregular word handling" do
      # These should be handled by our improved irregular words
      AmberCLI::Vendor::Inflector.pluralize("foot").should eq("feet")
      AmberCLI::Vendor::Inflector.pluralize("mouse").should eq("mice")
      AmberCLI::Vendor::Inflector.singularize("feet").should eq("foot")
      AmberCLI::Vendor::Inflector.singularize("mice").should eq("mouse")
    end
  end
end 