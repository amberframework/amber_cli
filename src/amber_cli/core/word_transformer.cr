require "inflector"

module AmberCLI::Core
  class WordTransformer
    # Common words that inflector.cr doesn't handle correctly
    CUSTOM_PLURALS = {
      "hero" => "heroes",
      "potato" => "potatoes",
      "echo" => "echoes",
      "embargo" => "embargoes",
      "tornado" => "tornadoes",
      "volcano" => "volcanoes",
      "buffalo" => "buffaloes", # though "buffalos" is also acceptable
    }

    CUSTOM_SINGULARS = {
      "heroes" => "hero", 
      "potatoes" => "potato",
      "echoes" => "echo",
      "embargoes" => "embargo", 
      "tornadoes" => "tornado",
      "volcanoes" => "volcano",
      "buffaloes" => "buffalo",
    }

    def self.transform(word : String, transformation : String, conventions : Hash(String, String) = {} of String => String) : String
      return word if word.empty?

      # Check for custom conventions first
      if conventions.has_key?(transformation)
        pattern = conventions[transformation]
        return pattern.gsub("{{word}}", word)
      end

      # Apply standard transformations using inflector.cr with custom overrides
      case transformation
      when "singular"
        # Check our custom singulars first
        if CUSTOM_SINGULARS.has_key?(word.downcase)
          CUSTOM_SINGULARS[word.downcase]
        else
          Inflector.singularize(word)
        end
      when "plural"
        # Check our custom plurals first
        if CUSTOM_PLURALS.has_key?(word.downcase)
          CUSTOM_PLURALS[word.downcase]
        else
          Inflector.pluralize(word)
        end
      when "pascal_case", "camel_case"
        # Convert to snake_case first if needed, then camelize
        snake_word = word.includes?("_") ? word : Inflector.underscore(word)
        Inflector.camelize(snake_word)
      when "snake_case"
        Inflector.underscore(word)
      when "kebab_case"
        # Convert to snake_case first, then dasherize
        snake_word = Inflector.underscore(word)
        Inflector.dasherize(snake_word)
      when "title_case"
        Inflector.titleize(word)
      when "upper_case"
        word.upcase
      when "lower_case"
        word.downcase
      when "constant_case"
        # Convert to snake_case, then uppercase
        snake_word = Inflector.underscore(word)
        snake_word.upcase
      when "humanize"
        Inflector.humanize(word)
      when "classify"
        Inflector.classify(word)
      when "tableize"
        # Convert to snake_case and pluralize for table names
        snake_word = Inflector.underscore(word)
        transform(snake_word, "plural") # Use our enhanced plural method
      when "foreign_key"
        Inflector.foreign_key(word)
      when "snake_case_plural"
        # Apply snake_case first, then pluralize
        snake_word = transform(word, "snake_case")
        transform(snake_word, "plural")
      when "pascal_case_plural"
        # Apply pascal_case first, then pluralize the result
        pascal_word = transform(word, "pascal_case")
        transform(pascal_word, "plural")
      when "kebab_case_plural"
        # Apply kebab_case first, then pluralize
        kebab_word = transform(word, "kebab_case")
        transform(kebab_word, "plural")
      else
        # Return original word if transformation not recognized
        word
      end
    end

    # Helper method for getting commonly used transformations at once
    def self.all_transformations(word : String, conventions : Hash(String, String) = {} of String => String) : Hash(String, String)
      transformations = {} of String => String
      
      %w(singular plural pascal_case snake_case kebab_case title_case 
         upper_case lower_case constant_case humanize classify tableize).each do |transformation|
        transformations[transformation] = transform(word, transformation, conventions)
      end
      
      transformations
    end

    # Helper method for Rails-like naming conventions
    def self.rails_conventions(word : String) : Hash(String, String)
      {
        "class_name" => transform(word, "pascal_case"),
        "table_name" => transform(word, "tableize"),
        "file_name" => transform(word, "snake_case"),
        "variable_name" => transform(word, "snake_case"),
        "constant_name" => transform(word, "constant_case"),
        "human_name" => transform(word, "humanize"),
        "route_name" => transform(word, "kebab_case")
      }
    end
  end
end 