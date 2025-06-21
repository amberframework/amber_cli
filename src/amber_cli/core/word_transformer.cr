module AmberCLI::Core
  class WordTransformer
    def self.transform(word : String, transformation : String, conventions : Hash(String, String) = {} of String => String) : String
      # Stub implementation - will be replaced with actual logic
      case transformation
      when "singular"
        word.gsub(/s$/, "")
      when "plural"
        word + "s"
      when "pascal_case", "camel_case"
        word.split(/[_\s-]/).map(&.capitalize).join
      when "snake_case"
        word.gsub(/([A-Z])/, "_\\1").downcase.gsub(/^_/, "")
      when "kebab_case"
        word.gsub(/[_\s]/, "-").downcase
      when "title_case"
        word.split(/[_\s-]/).map(&.capitalize).join(" ")
      when "upper_case"
        word.upcase
      when "lower_case"
        word.downcase
      when "constant_case"
        word.gsub(/[_\s-]/, "_").upcase
      when "snake_case_plural"
        transform(transform(word, "snake_case"), "plural")
      when "pascal_case_plural"
        transform(transform(word, "pascal_case"), "plural")
      else
        # Check for custom conventions
        if conventions.has_key?(transformation)
          pattern = conventions[transformation]
          pattern.gsub("{{word}}", word)
        else
          word
        end
      end
    end
  end
end 