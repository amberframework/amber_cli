require "./spec_helper"

describe AmberLSP::Rules::Library::StdlibReopen do
  describe "#check" do
    context "when a core type is defined" do
      it "reports a class definition" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::StdlibReopen.new, "class String\nend")
        issues.size.should eq(1)
        issues.first.message.should eq("Avoid reopening core type `String`")
      end

      it "reports a struct definition" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::StdlibReopen.new, "struct Array\nend")
        issues.size.should eq(1)
      end

      it "reports a module definition" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::StdlibReopen.new, "module Enumerable\nend")
        issues.size.should eq(1)
      end

      it "reports a globally qualified definition inside another module" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::StdlibReopen.new,
          "module Extensions\n  class ::String\n  end\nend",
        )
        issues.size.should eq(1)
      end
    end

    context "when a core name is nested in an application namespace" do
      it "passes" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::StdlibReopen.new,
          "module WidgetApp\n  class String\n  end\nend",
        )
        issues.should be_empty
      end
    end

    context "when another type is defined" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::StdlibReopen.new, "class Widget\nend")
        issues.should be_empty
      end
    end
  end
end
