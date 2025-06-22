# :nodoc:
require "../vendor/inflector/inflector"

# :nodoc:
module AmberCLI::Core
  # Provides string transformations for code generation using a hybrid approach.
  #
  # Uses Crystal's built-in String methods for simple transformations (camelcase, underscore, etc.)
  # and the inflector shard for complex English pluralization/singularization.
  #
  # ## Design Philosophy
  #
  # 1. **Crystal Standard Library First**: Uses Crystal's built-in String methods wherever possible
  # 2. **External Library for Complex Tasks**: Uses the inflector shard for English pluralization
  # 3. **Custom Overrides for Edge Cases**: Maintains custom mappings for words needing special handling
  # 4. **Convention Override Support**: Allows projects to define custom naming patterns
  #
  # ## Performance Characteristics
  #
  # - Fast transformations: Uses Crystal's native String methods (`String#camelcase`, `String#underscore`, etc.)
  # - Moderate complexity: Uses inflector for pluralization (requires linguistic rules)
  # - Memory efficient: Minimal object allocation, mostly string operations
  #
  # ## Dependency Justification
  #
  # The `inflector` shard dependency is retained because English pluralization is genuinely
  # complex (400+ irregular forms) and manual implementation would be incomplete and error-prone.
  # The shard is small (~100KB), stable, and well-tested.
  #
  # Examples of complex pluralization that would require manual maintenance:
  # child/children, mouse/mice, person/people, foot/feet, goose/geese, tooth/teeth, etc.
  #
  # ## Examples
  #
  # ```
  # # Fast Crystal built-in methods
  # WordTransformer.transform("UserProfile", "snake_case")   # => "user_profile"
  # WordTransformer.transform("user_profile", "pascal_case") # => "UserProfile"
  # WordTransformer.transform("blog_post", "kebab_case")     # => "blog-post"
  #
  # # Complex pluralization via inflector + custom overrides
  # WordTransformer.transform("user", "plural")  # => "users"
  # WordTransformer.transform("foot", "plural")  # => "feet" (custom override)
  # WordTransformer.transform("child", "plural") # => "children" (inflector)
  #
  # # Custom naming conventions
  # conventions = {"controller_suffix" => "{{word}}Controller"}
  # WordTransformer.transform("User", "controller_suffix", conventions) # => "UserController"
  # ```
  class WordTransformer
    # Common words that need special handling beyond standard English rules
    # Note: We now use a vendored, improved inflector library that fixes many issues
    CUSTOM_PLURALS = {
      "hero"    => "heroes",
      "potato"  => "potatoes",
      "echo"    => "echoes",
      "embargo" => "embargoes",
      "tornado" => "tornadoes",
      "volcano" => "volcanoes",
      "buffalo" => "buffaloes", # though "buffalos" is also acceptable
      # Note: "foot" -> "feet" is now fixed in our vendored inflector
    }

    CUSTOM_SINGULARS = {
      "heroes"    => "hero",
      "potatoes"  => "potato",
      "echoes"    => "echo",
      "embargoes" => "embargo",
      "tornadoes" => "tornado",
      "volcanoes" => "volcano",
      "buffaloes" => "buffalo",
      # Note: "feet" -> "foot" is now fixed in our vendored inflector
    }

    # :nodoc:
    # Built-in variables that can be used in templates
    BUILT_IN_VARIABLES = {
      "cli_version" => AmberCli::VERSION,
    }

    # Transforms a word using the specified transformation type.
    #
    # Checks for custom conventions first, allowing any transformation to be overridden
    # by team-specific or domain-specific naming rules. Falls back to standard transformations
    # using Crystal's built-in methods where possible for optimal performance.
    #
    # *word* is the input string to transform
    # *transformation* specifies the type of transformation to apply
    # *conventions* is an optional hash of custom naming patterns with `{{word}}` placeholder
    #
    # Returns the transformed word, or the original *word* if transformation is not recognized.
    #
    # ```
    # WordTransformer.transform("UserProfile", "snake_case") # => "user_profile"
    # WordTransformer.transform("blog_post", "pascal_case")  # => "BlogPost"
    # WordTransformer.transform("user", "plural")            # => "users"
    #
    # # With custom conventions
    # conventions = {"service_class" => "{{word}}Service"}
    # WordTransformer.transform("User", "service_class", conventions) # => "UserService"
    # ```
    def self.transform(word : String, transformation : String, conventions : Hash(String, String) = {} of String => String) : String
      return word if word.empty?

      # Check for custom conventions first - allows overriding any transformation
      if conventions.has_key?(transformation)
        pattern = conventions[transformation]

        # Only apply pascal case for specific well-known class/interface patterns
        # Be conservative to allow custom patterns to fully override behavior
        word_to_use = if pattern.includes?("{{word}}Service") ||
                         pattern.includes?("{{word}}Controller") ||
                         pattern.includes?("{{word}}Repository") ||
                         pattern.includes?("{{word}}Handler") ||
                         pattern.includes?("{{word}}Manager") ||
                         pattern.includes?("Api{{word}}") ||
                         pattern.includes?("I{{word}}")
                        # Convert to pascal case for well-known class-like patterns
                        word.includes?("_") ? word.camelcase : word.underscore.camelcase
                      else
                        # Use original word for all other patterns to preserve user intent
                        word
                      end

        return pattern.gsub("{{word}}", word_to_use)
      end

      # Apply transformations using Crystal's built-in methods where possible
      case transformation
      when "singular"
        # Check our custom singulars first, then use inflector for complex cases
        CUSTOM_SINGULARS[word.downcase]? || AmberCLI::Vendor::Inflector.singularize(word)
      when "plural"
        # Check our custom plurals first, then use inflector for complex cases
        CUSTOM_PLURALS[word.downcase]? || AmberCLI::Vendor::Inflector.pluralize(word)
      when "pascal_case", "camel_case"
        # Use Crystal's built-in camelcase method - much faster than inflector
        word.includes?("_") ? word.camelcase : word.underscore.camelcase
      when "snake_case"
        # Use Crystal's built-in underscore method - handles PascalCase -> snake_case
        word.underscore
      when "kebab_case"
        # Convert to snake_case using Crystal's method, then replace underscores with dashes
        word.underscore.gsub("_", "-")
      when "title_case"
        # Build title case using Crystal's string methods instead of inflector
        word.underscore.split("_").map(&.capitalize).join(" ")
      when "upper_case"
        word.upcase
      when "lower_case"
        word.downcase
      when "constant_case"
        # Convert to snake_case using Crystal's method, then uppercase
        word.underscore.upcase
      when "humanize"
        # Simple humanization using Crystal's methods instead of inflector
        word.underscore.gsub("_", " ").capitalize
      when "classify"
        # Use inflector for classify as it handles more complex cases (plurals -> singular class names)
        AmberCLI::Vendor::Inflector.classify(word)
      when "tableize"
        # Convert to snake_case and pluralize for table names
        snake_word = word.underscore
        transform(snake_word, "plural") # Use our enhanced plural method
      when "foreign_key"
        # Use inflector for foreign key as it has specific Rails conventions
        AmberCLI::Vendor::Inflector.foreign_key(word)
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

    # Returns all common transformations for a word as a hash.
    #
    # Applies each supported transformation type to the given *word* and returns
    # a hash mapping transformation names to their results. Custom *conventions*
    # are applied when provided.
    #
    # ```
    # result = WordTransformer.all_transformations("blog_post")
    # result["pascal_case"] # => "BlogPost"
    # result["snake_case"]  # => "blog_post"
    # result["plural"]      # => "blog_posts"
    # ```
    def self.all_transformations(word : String, conventions : Hash(String, String) = {} of String => String) : Hash(String, String)
      transformations = {} of String => String

      %w(singular plural pascal_case snake_case kebab_case title_case
        upper_case lower_case constant_case humanize classify tableize).each do |transformation|
        transformations[transformation] = transform(word, transformation, conventions)
      end

      transformations
    end

    # Returns Rails-style naming conventions for a word.
    #
    # Provides a hash of conventional names commonly used in Rails applications,
    # including class names, table names, file names, and route names.
    #
    # ```
    # result = WordTransformer.rails_conventions("blog_post")
    # result["class_name"] # => "BlogPost"
    # result["table_name"] # => "blog_posts"
    # result["file_name"]  # => "blog_post"
    # result["route_name"] # => "blog-post"
    # ```
    def self.rails_conventions(word : String) : Hash(String, String)
      {
        "class_name"    => transform(word, "pascal_case"),
        "table_name"    => transform(word, "tableize"),
        "file_name"     => transform(word, "snake_case"),
        "variable_name" => transform(word, "snake_case"),
        "constant_name" => transform(word, "constant_case"),
        "human_name"    => transform(word, "humanize"),
        "route_name"    => transform(word, "kebab_case"),
      }
    end

    # Returns `true` if the transformation type is supported.
    #
    # Use this method to validate transformation names before calling `#transform`.
    #
    # ```
    # WordTransformer.supports_transformation?("pascal_case")  # => true
    # WordTransformer.supports_transformation?("invalid_type") # => false
    # ```
    def self.supports_transformation?(transformation : String) : Bool
      case transformation
      when "singular", "plural", "pascal_case", "camel_case", "snake_case",
           "kebab_case", "title_case", "upper_case", "lower_case", "constant_case",
           "humanize", "classify", "tableize", "foreign_key", "snake_case_plural",
           "pascal_case_plural", "kebab_case_plural"
        true
      else
        false
      end
    end

    # Returns an array of all supported transformation names.
    #
    # Use this method to discover available transformation types or for validation.
    #
    # ```
    # transformations = WordTransformer.supported_transformations
    # transformations.includes?("pascal_case") # => true
    # ```
    def self.supported_transformations : Array(String)
      %w(singular plural pascal_case camel_case snake_case kebab_case title_case
        upper_case lower_case constant_case humanize classify tableize foreign_key
        snake_case_plural pascal_case_plural kebab_case_plural)
    end
  end
end
