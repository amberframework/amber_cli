# Vendored Inflector Library
# Based on phoffer/inflector.cr (MIT License)
# https://github.com/phoffer/inflector.cr
#
# Modified for Amber CLI to include only required methods and improved irregular words.
# Enhanced with AI-powered fallback for unknown transformations.

require "./irregular_words"
require "./ai_transformer"

module AmberCLI::Vendor::Inflector
  extend self

  # Storage for inflection rules
  @@plurals = [] of {Regex, String}
  @@singulars = [] of {Regex, String}
  @@uncountables = [] of String

  # Returns the plural form of the word in the string.
  #
  #   pluralize("post")             # => "posts"
  #   pluralize("octopus")          # => "octopi"
  #   pluralize("sheep")            # => "sheep"
  #   pluralize("foot")             # => "feet"  # Fixed!
  #   pluralize("child")            # => "children"
  def pluralize(word : String) : String
    # Try local rules first
    local_result = apply_inflections(word, @@plurals)
    
    # If local rules didn't change the word (except for simple 's' addition), 
    # and it's not an uncountable word, try AI fallback
    if should_try_ai_fallback?(word, local_result, is_pluralize: true)
      if ai_result = AITransformer.transform_with_ai(word, "plural")
        return ai_result
      end
    end
    
    local_result
  end

  # The reverse of #pluralize, returns the singular form of a word in a string.
  #
  #   singularize('posts')          # => "post"
  #   singularize('octopi')         # => "octopus"
  #   singularize('sheep')          # => "sheep"
  #   singularize('feet')           # => "foot"  # Fixed!
  #   singularize('children')       # => "child"
  def singularize(word : String) : String
    # Try local rules first
    local_result = apply_inflections(word, @@singulars)
    
    # If local rules didn't change the word much, try AI fallback
    if should_try_ai_fallback?(word, local_result, is_pluralize: false)
      if ai_result = AITransformer.transform_with_ai(word, "singular")
        return ai_result
      end
    end
    
    local_result
  end

  # Creates a class name from a plural table name like Rails does for table
  # names to models. Note that this returns a string and not a Class.
  #
  #   classify("egg_and_hams") # => "EggAndHam"
  #   classify("posts")        # => "Post"
  def classify(table_name : String) : String
    # Use Crystal's built-in camelcase method instead of custom implementation
    singularize(table_name.sub(/.*\./, "")).camelcase
  end

  def classify(table_name : Symbol) : String
    classify(table_name.to_s)
  end

  # Creates a foreign key name from a class name.
  #
  #   foreign_key("Message")        # => "message_id"
  #   foreign_key("Admin::Post")    # => "post_id"
  def foreign_key(class_name : String, separate_class_name_and_id_with_underscore = true) : String
    # Use Crystal's built-in underscore method and simple demodulize
    demodulized = demodulize(class_name)
    if separate_class_name_and_id_with_underscore
      demodulized.underscore + "_id"
    else
      demodulized.underscore.gsub("_", "") + "id"
    end
  end

  # Removes the module part from the expression in the string.
  #
  #   demodulize("ActiveRecord::CoreExtensions::String::Inflections") # => "Inflections"
  #   demodulize("Inflections")                                       # => "Inflections"
  private def demodulize(path : String) : String
    if i = path.rindex("::")
      path[(i+2)..-1]
    else
      path
    end
  end

  # Apply inflection rules for pluralize and singularize
  private def apply_inflections(word : String, rules : Array({Regex, String})) : String
    result = word.to_s

    return result if result.empty?
    
    # Check if word is uncountable
    word_match = result.downcase[/\b\w+\Z/]?
    return result if word_match && @@uncountables.includes?(word_match)

    # Check irregular words first
    if irregular_result = IrregularWords.transform(result, rules == @@plurals)
      return irregular_result
    end

    # Apply regex rules - find the first matching rule and apply it
    rules.each do |rule_and_replacement|
      rule, replacement = rule_and_replacement
      if result =~ rule
        result = result.gsub(rule) do |s, match|
          repl = replacement
          if match.size > 1
            repl = repl.gsub("\\1", match[1]? || "")
          end
          if match.size > 2
            repl = repl.gsub("\\2", match[2]? || "")
          end
          repl
        end
        break # Important: stop after first match
      end
    end
    result
  end

  # Determine if we should try AI fallback based on local rule results
  private def should_try_ai_fallback?(original : String, local_result : String, is_pluralize : Bool) : Bool
    return false if original.empty? || local_result.empty?
    
    # Skip AI for uncountable words
    word_match = original.downcase[/\b\w+\Z/]?
    return false if word_match && @@uncountables.includes?(word_match)
    
    # For pluralization: if result is just original + "s", consider AI
    if is_pluralize
      return local_result == original + "s" && original.size > 2
    else
      # For singularization: if result removed "s" but word seems complex, try AI
      return local_result == original.rchop("s") && original.size > 4
    end
  end

  # Configure AI transformer (convenience method)
  def self.configure_ai
    yield(AITransformer)
  end

  # Initialize the inflection rules (similar to seed.cr from original)
  def self.setup_rules
    # Plural rules - ordered from most specific to least specific
    @@plurals = [
      {/^(ox)$/i,                   "\\1en"},
      {/^(oxen)$/i,                 "\\1"},
      {/^(m|l)ouse$/i,              "\\1ice"},
      {/^(m|l)ice$/i,               "\\1ice"},
      {/^(ax|test)is$/i,            "\\1es"},
      {/(octop|vir)us$/i,           "\\1i"},
      {/(octop|vir)i$/i,            "\\1i"},
      {/(alias|status)$/i,          "\\1es"},
      {/(bu)s$/i,                   "\\1ses"},
      {/(buffal|tomat)o$/i,         "\\1oes"},
      {/([ti])um$/i,                "\\1a"},
      {/([ti])a$/i,                 "\\1a"},
      {/sis$/i,                     "ses"},
      {/(?:([^f])fe|([lrae])f)$/i,  "\\1\\2ves"},
      {/(hive)$/i,                  "\\1s"},
      {/([^aeiouy]|qu)y$/i,         "\\1ies"},
      {/(x|ch|ss|sh)$/i,            "\\1es"},
      {/(matr|vert|ind)(?:ix|ex)$/i, "\\1ices"},
      {/(quiz)$/i,                  "\\1zes"},
      {/s$/i,                       "s"},
      {/$/,                         "s"},  # Most general rule goes last
    ]

    # Singular rules - ordered from most specific to least specific
    @@singulars = [
      {/^(ox)en/i,                                                     "\\1"},
      {/^(m|l)ice$/i,                                                  "\\1ouse"},
      {/^(a)x[ie]s$/i,                                                 "\\1xis"},
      {/(n)ews$/i,                                                     "\\1ews"},
      {/(s)eries$/i,                                                   "\\1eries"},
      {/(m)ovies$/i,                                                   "\\1ovie"},
      {/(database)s$/i,                                                "\\1"},
      {/(quiz)zes$/i,                                                  "\\1"},
      {/(matr)ices$/i,                                                 "\\1ix"},
      {/(vert|ind)ices$/i,                                             "\\1ex"},
      {/(octop|vir)(us|i)$/i,                                          "\\1us"},
      {/(alias|status)(es)?$/i,                                        "\\1"},
      {/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$/i, "\\1sis"},
      {/(^analy)(sis|ses)$/i,                                          "\\1sis"},
      {/(cris|test)(is|es)$/i,                                         "\\1is"},
      {/([ti])a$/i,                                                    "\\1um"},
      {/([^f])ves$/i,                                                  "\\1fe"},
      {/([lrae])ves$/i,                                                "\\1f"},
      {/([^aeiouy]|qu)ies$/i,                                          "\\1y"},
      {/(hive)s$/i,                                                    "\\1"},
      {/(tive)s$/i,                                                    "\\1"},
      {/(x|ch|ss|sh)es$/i,                                             "\\1"},
      {/(bus)(es)?$/i,                                                 "\\1"},
      {/(o)es$/i,                                                      "\\1"},
      {/(shoe)s$/i,                                                    "\\1"},
      {/(ss)$/i,                                                       "\\1"},
      {/s$/i,                                                          ""},  # Most general rule goes last
    ]

    # Uncountable words
    @@uncountables = %w(equipment information rice money species series fish sheep jeans police)
  end
end

# Initialize the rules when the module is loaded
AmberCLI::Vendor::Inflector.setup_rules
