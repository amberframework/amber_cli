require "./spec_helper"

describe AmberLSP::Rules::Diagnostic do
  describe "#to_lsp_json" do
    it "returns a hash with correct LSP structure" do
      diagnostic = AmberLSP::Rules::Diagnostic.new(
        range: AmberLSP::Rules::TextRange.new(
          AmberLSP::Rules::Position.new(5, 10),
          AmberLSP::Rules::Position.new(5, 20)
        ),
        severity: AmberLSP::Rules::Severity::Warning,
        code: "amber/test-rule",
        message: "This is a test diagnostic"
      )

      json = diagnostic.to_lsp_json

      range = json["range"]
      range["start"]["line"].as_i.should eq(5)
      range["start"]["character"].as_i.should eq(10)
      range["end"]["line"].as_i.should eq(5)
      range["end"]["character"].as_i.should eq(20)

      json["severity"].as_i.should eq(2) # Warning = 2
      json["code"].as_s.should eq("amber/test-rule")
      json["source"].as_s.should eq("amber-lsp")
      json["message"].as_s.should eq("This is a test diagnostic")
    end

    it "uses custom source when provided" do
      diagnostic = AmberLSP::Rules::Diagnostic.new(
        range: AmberLSP::Rules::TextRange.new(
          AmberLSP::Rules::Position.new(0, 0),
          AmberLSP::Rules::Position.new(0, 1)
        ),
        severity: AmberLSP::Rules::Severity::Error,
        code: "test",
        message: "error",
        source: "custom-source"
      )

      json = diagnostic.to_lsp_json
      json["source"].as_s.should eq("custom-source")
    end
  end
end

describe AmberLSP::Rules::Severity do
  it "has correct integer values for LSP protocol" do
    AmberLSP::Rules::Severity::Error.value.should eq(1)
    AmberLSP::Rules::Severity::Warning.value.should eq(2)
    AmberLSP::Rules::Severity::Information.value.should eq(3)
    AmberLSP::Rules::Severity::Hint.value.should eq(4)
  end
end
