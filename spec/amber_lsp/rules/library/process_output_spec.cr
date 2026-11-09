require "./spec_helper"

describe AmberLSP::Rules::Library::ProcessOutput do
  describe "#check" do
    context "when a receiverless output method is called" do
      it "reports each process output method" do
        %w[puts print printf p pp].each do |output_method_name|
          issues = library_rule_diagnostics(AmberLSP::Rules::Library::ProcessOutput.new, "#{output_method_name}(1)")
          issues.size.should eq(1)
        end
      end
    end

    context "when output is sent to a receiver" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::ProcessOutput.new, "io.puts(1)")
        issues.should be_empty
      end
    end
  end
end
