require "./spec_helper"

describe AmberLSP::Rules::Library::DisabledCertificateVerification do
  describe "#check" do
    context "when VerifyMode::NONE is used" do
      it "reports the path" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::DisabledCertificateVerification.new,
          "OpenSSL::SSL::VerifyMode::NONE",
        )
        issues.size.should eq(1)
        issues.first.message.should eq("Keep certificate verification enabled")
      end
    end

    context "when another verification mode is used" do
      it "passes" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::DisabledCertificateVerification.new,
          "OpenSSL::SSL::VerifyMode::PEER",
        )
        issues.should be_empty
      end
    end
  end
end
