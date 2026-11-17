require "./spec_helper"

describe AmberLSP::Rules::Library::UnsynchronizedClassVariable do
  describe "#check" do
    context "when a collection class variable is assigned" do
      it "reports an Array value" do
        source_code = "class Cache\n  @@items = [] of String\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UnsynchronizedClassVariable.new, source_code)
        issues.size.should eq(1)
      end

      it "reports a Hash value" do
        source_code = "class Cache\n  @@items = {} of String => String\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UnsynchronizedClassVariable.new, source_code)
        issues.size.should eq(1)
      end

      it "reports a Set value" do
        source_code = "class Cache\n  @@items = Set(String).new\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UnsynchronizedClassVariable.new, source_code)
        issues.size.should eq(1)
      end
    end

    context "when the file uses Mutex or Atomic" do
      it "passes the collection class variable" do
        source_code = "class Cache\n  @@items = [] of String\n  LOCK = Mutex.new\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UnsynchronizedClassVariable.new, source_code)
        issues.should be_empty
      end
    end

    context "when the class variable has a collection type declaration" do
      it "reports an unguarded declaration" do
        source_code = "class Cache\n  @@items : Array(String)\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UnsynchronizedClassVariable.new, source_code)
        issues.size.should eq(1)
      end
    end
  end
end
