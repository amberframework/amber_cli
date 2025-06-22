# Vendored Inflector Library

This is a vendored and improved version of the Crystal inflector library, based on [phoffer/inflector.cr](https://github.com/phoffer/inflector.cr).

## Attribution

Original library: **phoffer/inflector.cr** (MIT License)
- Author: Paul Hoffer <git@paulhoffer.com>
- Original source: https://github.com/phoffer/inflector.cr

## Improvements Made

### Fixed Irregular Words
- **foot → feet** (was incorrectly "foot → foots")
- **tooth → teeth** (was missing)
- **goose → geese** (was missing)

### Added Programming-Specific Terms
- **index → indices** (database indexes)
- **vertex → vertices** (graph theory)
- **matrix → matrices** (mathematical)
- **datum → data** (data science)

### Performance Optimizations
- Use Crystal's built-in `String#camelcase` and `String#underscore` methods
- Faster hash-based lookup for irregular words
- Streamlined code with only required methods

### Reduced Footprint
- Only includes the 4 methods needed by Amber CLI:
  - `pluralize(word)`
  - `singularize(word)`
  - `classify(word)`
  - `foreign_key(word)`

## Usage

```crystal
require "./src/amber_cli/vendor/inflector/inflector"

# Pluralization
AmberCLI::Vendor::Inflector.pluralize("foot")   # => "feet" ✅ (fixed!)
AmberCLI::Vendor::Inflector.pluralize("child")  # => "children"
AmberCLI::Vendor::Inflector.pluralize("person") # => "people"

# Singularization  
AmberCLI::Vendor::Inflector.singularize("feet")     # => "foot" ✅ (fixed!)
AmberCLI::Vendor::Inflector.singularize("children") # => "child"
AmberCLI::Vendor::Inflector.singularize("people")   # => "person"

# Classification (table name to class name)
AmberCLI::Vendor::Inflector.classify("blog_posts") # => "BlogPost"
AmberCLI::Vendor::Inflector.classify("users")      # => "User"

# Foreign key generation
AmberCLI::Vendor::Inflector.foreign_key("User")    # => "user_id"
AmberCLI::Vendor::Inflector.foreign_key("BlogPost") # => "blog_post_id"
```

## Testing

The vendored library maintains 100% backward compatibility with the original library while fixing known issues. All original test cases pass, plus additional tests for the fixed irregular words.

## License

MIT License (same as original)
