# AI Inflector Configuration
# 
# Configure AI-powered inflection fallback for unknown words.
# This is optional and disabled by default.

# Uncomment and configure to enable AI-powered inflections:

# AmberCLI::Vendor::Inflector.configure_ai do |ai|
#   ai.configure do |config|
#     config.enabled = true
#     config.api_key = ENV["OPENAI_API_KEY"]?
#     config.model = "gpt-3.5-turbo"  # or "gpt-4" for better accuracy
#     config.timeout = 5.seconds
#     config.max_retries = 2
#   end
# end

# Alternative providers can be configured by changing the api_url:
#
# For Anthropic Claude:
# config.api_url = "https://api.anthropic.com/v1/messages"
# config.api_key = ENV["ANTHROPIC_API_KEY"]?
#
# For local models (like Ollama):
# config.api_url = "http://localhost:11434/v1/chat/completions"
# config.api_key = nil  # No API key needed for local models

# Usage Examples:
#
# With AI enabled, these work automatically:
# AmberCLI::Vendor::Inflector.pluralize("corpus")    # => "corpora" (via AI)
# AmberCLI::Vendor::Inflector.pluralize("phenomenon") # => "phenomena" (via AI)
# AmberCLI::Vendor::Inflector.singularize("alumni")   # => "alumnus" (via AI)
#
# Common words are still handled by fast local rules:
# AmberCLI::Vendor::Inflector.pluralize("user")      # => "users" (local)
# AmberCLI::Vendor::Inflector.pluralize("child")     # => "children" (local) 