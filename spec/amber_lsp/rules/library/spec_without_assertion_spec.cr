require "./spec_helper"

describe AmberLSP::Rules::Library::SpecWithoutAssertion do
  describe "#check" do
    context "golden: a supported assertion call is present" do
      it "accepts direct assertion methods and the default prefixes" do
        source_code = "describe \"assertions\" do\n  it \"uses should\" do\n    1.should eq(1)\n  end\n  it \"uses should_not\" do\n    1.should_not eq(2)\n  end\n  it \"uses expect_raises\" do\n    expect_raises(ArgumentError) { raise ArgumentError.new(\"expected\") }\n  end\n  it \"uses fail\" do\n    fail(\"unreachable\")\n  end\n  it \"uses an assert prefix\" do\n    assert_equal(1, 1)\n  end\n  it \"uses an expect prefix\" do\n    expect_value(1)\n  end\n  it \"uses a verify prefix\" do\n    verify_value(1)\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SpecWithoutAssertion.new, source_code, "spec/sample_spec.cr")
        issues.should be_empty
      end
    end

    context "at the boundary: an example contains no assertion" do
      it "reports the empty example" do
        source_code = "describe \"a feature\" do\n  it \"builds a response\" do\n    build_response\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SpecWithoutAssertion.new, source_code, "spec/sample_spec.cr")
        issues.size.should eq(1)
        issues.first.message.should contain("Add an assertion")
      end
    end

    context "just past the boundary: the source is not a spec file" do
      it "passes" do
        source_code = "def check_response : Nil\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SpecWithoutAssertion.new, source_code, "src/example.cr")
        issues.should be_empty
      end
    end
  end
end
