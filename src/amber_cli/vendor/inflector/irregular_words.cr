# Irregular word transformations that don't follow standard pluralization rules
# This includes common English irregulars plus programming-specific terms

module AmberCLI::Vendor::Inflector::IrregularWords
  extend self

  # Define irregular pluralization pairs: [singular, plural]
  IRREGULAR_PAIRS = [
    # Common English irregulars from original library
    ["person", "people"],
    ["man", "men"],
    ["woman", "women"],
    ["child", "children"],
    ["sex", "sexes"],
    ["move", "moves"],
    ["zombie", "zombies"],
    
    # Fixed irregulars that were missing or wrong
    ["foot", "feet"],
    ["tooth", "teeth"],
    ["goose", "geese"],
    ["mouse", "mice"],        # This was missing!
    ["half", "halves"],       # Fix for halves → half test
    
    # Programming/database specific terms
    ["index", "indices"],     # database indexes
    ["vertex", "vertices"],   # graph vertices
    ["matrix", "matrices"],   # mathematical matrices
    ["datum", "data"],        # data vs datum
    
    # Add more as needed
  ]

  # Create lookup hashes for fast access
  SINGULAR_TO_PLURAL = IRREGULAR_PAIRS.to_h
  PLURAL_TO_SINGULAR = IRREGULAR_PAIRS.map { |pair| [pair[1], pair[0]] }.to_h

  # Transform a word based on irregular rules
  # Returns nil if no irregular rule applies
  def transform(word : String, pluralize : Bool) : String?
    downcase_word = word.downcase
    
    if pluralize
      # Check if this is a singular form that has an irregular plural
      if plural = SINGULAR_TO_PLURAL[downcase_word]?
        return preserve_case(word, plural)
      end
    else
      # Check if this is a plural form that has an irregular singular
      if singular = PLURAL_TO_SINGULAR[downcase_word]?
        return preserve_case(word, singular)
      end
    end
    
    nil
  end

  # Preserve the case pattern of the original word when applying transformation
  private def preserve_case(original : String, transformed : String) : String
    return transformed if original.empty?
    
    # If original is all uppercase, make result uppercase
    if original == original.upcase
      return transformed.upcase
    end
    
    # If original starts with uppercase, capitalize result
    if original[0] == original[0].upcase
      return transformed.capitalize
    end
    
    # Otherwise return lowercase
    transformed.downcase
  end
end
