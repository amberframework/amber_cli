# AI-Powered Inflector Fallback System
#
# When local rules don't handle a transformation, this system can fall back to AI
# for smart linguistic transformations. Results are cached for performance.

require "http/client"
require "json"

module AmberCLI::Vendor::Inflector::AITransformer
  extend self

  # Configuration for AI service
  class Config
    property api_key : String?
    property api_url : String = "https://api.openai.com/v1/chat/completions"
    property model : String = "gpt-3.5-turbo"
    property timeout : Time::Span = 5.seconds
    property max_retries : Int32 = 2
    property enabled : Bool = false

    def initialize
    end
  end

  # Cache for AI transformation results
  @@cache = {} of String => String
  @@config = Config.new

  # Configure the AI transformer
  def configure(&)
    yield(@@config)
  end

  # Transform a word using AI if local rules fail
  # Returns nil if AI is disabled, unavailable, or fails
  def transform_with_ai(word : String, transformation : String) : String?
    return nil unless @@config.enabled
    return nil if word.empty?

    # Check cache first
    cache_key = "#{word}:#{transformation}"
    if cached_result = @@cache[cache_key]?
      return cached_result
    end

    # Try AI transformation
    if result = call_ai_service(word, transformation)
      @@cache[cache_key] = result
      return result
    end

    nil
  end

  # Clear the transformation cache
  def clear_cache
    @@cache.clear
  end

  # Get cache statistics
  def cache_stats
    {
      size: @@cache.size,
      keys: @@cache.keys.sort,
    }
  end

  # Call AI service to transform the word
  private def call_ai_service(word : String, transformation : String) : String?
    return nil unless @@config.api_key

    prompt = build_prompt(word, transformation)

    retries = 0
    while retries <= @@config.max_retries
      begin
        response = make_api_request(prompt)
        if result = parse_response(response)
          return result.strip
        end
      rescue ex : Exception
        puts "AI transformer error (attempt #{retries + 1}): #{ex.message}" if ENV["DEBUG"]?
      end

      retries += 1
      sleep(0.5.seconds) if retries <= @@config.max_retries
    end

    nil
  end

  # Build a focused prompt for the transformation
  private def build_prompt(word : String, transformation : String) : String
    case transformation
    when "plural"
      <<-PROMPT
      Transform this English word to its plural form. 
      Return only the plural form, nothing else.
      
      Word: #{word}
      
      Examples:
      - mouse → mice
      - child → children  
      - person → people
      - foot → feet
      - datum → data
      
      Plural:
      PROMPT
    when "singular"
      <<-PROMPT
      Transform this English word to its singular form.
      Return only the singular form, nothing else.
      
      Word: #{word}
      
      Examples:
      - mice → mouse
      - children → child
      - people → person
      - feet → foot
      - data → datum
      
      Singular:
      PROMPT
    else
      <<-PROMPT
      Transform this English word using the transformation: #{transformation}
      Return only the transformed word, nothing else.
      
      Word: #{word}
      Transformation: #{transformation}
      
      Result:
      PROMPT
    end
  end

  # Make HTTP request to AI service
  private def make_api_request(prompt : String) : String
    headers = HTTP::Headers{
      "Content-Type"  => "application/json",
      "Authorization" => "Bearer #{@@config.api_key}",
    }

    body = {
      model:    @@config.model,
      messages: [
        {
          role:    "user",
          content: prompt,
        },
      ],
      max_tokens:  10,  # We only need a single word
      temperature: 0.1, # Low temperature for consistent results
    }.to_json

    client = HTTP::Client.new(URI.parse(@@config.api_url))
    client.connect_timeout = @@config.timeout
    client.read_timeout = @@config.timeout

    response = client.post(@@config.api_url, headers: headers, body: body)
    response.body
  end

  # Parse AI service response
  private def parse_response(response_body : String) : String?
    parsed = JSON.parse(response_body)

    if choices = parsed["choices"]?.try(&.as_a)
      if choice = choices[0]?
        if message = choice["message"]?
          if content = message["content"]?.try(&.as_s)
            # Clean up the response - remove extra whitespace, quotes, etc.
            cleaned = content.strip.gsub(/^["']|["']$/, "")
            return cleaned unless cleaned.empty?
          end
        end
      end
    end

    nil
  rescue JSON::ParseException
    nil
  end
end
