module AmberCLI::Agent::AgentSetupGuidance
  GENERATED_HOOK_VERSION = "5"
  DOCUMENT_START         = "<!-- amber-agent-loop:start -->"
  DOCUMENT_END           = "<!-- amber-agent-loop:end -->"

  REQUIRED_LOOKUP_INSTRUCTION = "Before writing code that calls Grant, Amber, asset_pipeline, or Crystal standard library methods, list each method you will call and run `amber-lsp lookup 'Type.method'` (class method) or `amber-lsp lookup 'Type#method'` (instance method) for each one, adding `--verify` when the answer is unknown. Use exactly the signatures and return types it reports, and follow any card note it prints."
end
