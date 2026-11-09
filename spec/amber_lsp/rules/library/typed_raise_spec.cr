require "./spec_helper"

describe AmberLSP::Rules::Library::TypedRaise do
  describe "#check" do
    context "when raise receives a string message" do
      it "reports a string literal" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::TypedRaise.new, "raise \"failure\"")
        issues.size.should eq(1)
        issues.first.message.should eq("Raise a named error instead of a string message")
      end

      it "reports an interpolated string message" do
        source_code = String.build do |source_buffer|
          source_buffer << "raise "
          source_buffer << 34.chr
          source_buffer << "failure: "
          source_buffer << 35.chr
          source_buffer << "{reason}"
          source_buffer << 34.chr
        end
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::TypedRaise.new, source_code)
        issues.size.should eq(1)
      end
    end

    context "when raise receives an error object" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::TypedRaise.new, "raise error")
        issues.should be_empty
      end
    end

    context "when a compile-time raise appears" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::TypedRaise.new, "{% raise \"failure\" %}")
        issues.should be_empty
      end
    end
  end
end
