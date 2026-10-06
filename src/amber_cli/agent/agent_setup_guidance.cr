require "../../amber_lsp/project_context"

module AmberCLI::Agent::AgentSetupGuidance
  GENERATED_HOOK_VERSION       = "6"
  DOCUMENT_START               = "<!-- amber-agent-loop:start -->"
  DOCUMENT_END                 = "<!-- amber-agent-loop:end -->"
  PLAIN_CRYSTAL_READINESS_ITEM = "plain Crystal project: Amber rules do not apply; lookup and Crystal hints are active"

  REQUIRED_LOOKUP_INSTRUCTION               = "Before writing code that calls Grant, Amber, asset_pipeline, or Crystal standard library methods, list each method you will call and run `amber-lsp lookup 'Type.method'` (class method) or `amber-lsp lookup 'Type#method'` (instance method) for each one, adding `--verify` when the answer is unknown. Use exactly the signatures and return types it reports, and follow any card note it prints."
  PLAIN_CRYSTAL_REQUIRED_LOOKUP_INSTRUCTION = "Before writing code that calls Crystal standard library methods or methods from this project's own shards, list each method you will call and run `amber-lsp lookup 'Type.method'` (class method) or `amber-lsp lookup 'Type#method'` (instance method) for each one, adding `--verify` when the answer is unknown. Use exactly the signatures and return types it reports, and follow any card note it prints."

  def self.uses_amber_v2_stack?(project_root : String) : Bool
    AmberLSP::ProjectContext.detect(project_root).stack_project?
  end

  def self.required_lookup_instruction_for(project_root : String) : String
    if uses_amber_v2_stack?(project_root)
      REQUIRED_LOOKUP_INSTRUCTION
    else
      PLAIN_CRYSTAL_REQUIRED_LOOKUP_INSTRUCTION
    end
  end
end
