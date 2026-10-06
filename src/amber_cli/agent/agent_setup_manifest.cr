require "json"

module AmberCLI::Agent
  class AgentSetupManifest
    include JSON::Serializable

    property amber_cli_version : String
    property minimum_amber_lsp_version : String
    property generated_hook_version : String

    def initialize(
      @amber_cli_version : String,
      @minimum_amber_lsp_version : String,
      @generated_hook_version : String,
    )
    end
  end
end
