module AmberLSP::Lookup
  alias EmbeddedAPICardYAML = Tuple(String, String)

  # :nodoc:
  EMBEDDED_API_CARD_YAMLS = [{
    "crystal.yml",
    {{ read_file("src/amber_lsp/cards/crystal.yml") }},
  }]
end
