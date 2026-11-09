require "../../spec_helper"

def library_rule_diagnostics(
  rule : AmberLSP::Rules::BaseRule,
  source_code : String,
  file_path : String = "src/sample.cr",
) : Array(AmberLSP::Rules::Diagnostic)
  rule.check(file_path, source_code)
end
