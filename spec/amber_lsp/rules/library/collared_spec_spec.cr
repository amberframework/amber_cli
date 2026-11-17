require "./spec_helper"

describe AmberLSP::Rules::Library::CollaredSpec do
  describe "#check" do
    context "golden: a method describe has both collars" do
      it "passes a complete instance method shape" do
        source_code = "describe \"#sample\" do\n  context \"at the boundary: largest accepted value\" do\n    it \"accepts the value\" do\n      value.should eq(10)\n    end\n  end\n  context \"just past the boundary: first rejected value\" do\n    it \"rejects the value\" do\n      expect_raises(ArgumentError) { raise ArgumentError.new(\"outside\") }\n    end\n  end\n  it \"accepts a typical value\" do\n    value.should eq(5)\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, source_code, "spec/sample_spec.cr")
        issues.should be_empty
      end

      it "passes a complete class method shape" do
        source_code = "describe \".sample\" do\n  context \"at the boundary: largest accepted value\" do\n    it \"accepts the value\" do\n      value.should eq(10)\n    end\n  end\n  context \"just past the boundary: first rejected value\" do\n    it \"rejects the value\" do\n      expect_raises(ArgumentError) { raise ArgumentError.new(\"outside\") }\n    end\n  end\n  it \"accepts a typical value\" do\n    value.should eq(5)\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, source_code, "spec/sample_spec.cr")
        issues.should be_empty
      end
    end

    context "at the boundary: a golden case and expected failure are present" do
      it "reports only the missing at-the-boundary context" do
        source_code = "describe \"#sample\" do\n  context \"just past the boundary: first rejected value\" do\n    it \"rejects the value\" do\n      expect_raises(ArgumentError) { raise ArgumentError.new(\"outside\") }\n    end\n  end\n  it \"accepts a typical value\" do\n    value.should eq(5)\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, source_code, "spec/sample_spec.cr")
        issues.map(&.message).should eq([AmberLSP::Rules::Library::Support::CollaredSpecShape::MSG_BOUNDARY_CONTEXT])
      end
    end

    context "just past the boundary: a context has no expected-failure assertion" do
      it "reports the missing expected-failure assertion" do
        source_code = "describe \"#sample\" do\n  context \"at the boundary: largest accepted value\" do\n    it \"accepts the value\" do\n      value.should eq(10)\n    end\n  end\n  context \"just past the boundary: first rejected value\" do\n    it \"rejects the value\" do\n      value.should eq(10)\n    end\n  end\n  it \"accepts a typical value\" do\n    value.should eq(5)\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, source_code, "spec/sample_spec.cr")
        issues.map(&.message).should eq([AmberLSP::Rules::Library::Support::CollaredSpecShape::MSG_EXPECTED_FAILURE])
      end
    end

    context "when a describe has a reasoned exemption" do
      it "passes" do
        source_code = "# collar: none, this generated callback has no input boundary\ndescribe \"#generated_callback\" do\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, source_code, "spec/sample_spec.cr")
        issues.should be_empty
      end
    end

    context "when source is not a spec file" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::CollaredSpec.new, "describe \"#sample\" do\nend", "src/sample.cr")
        issues.should be_empty
      end
    end
  end
end
