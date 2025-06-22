# Inflector Library Migration Plan

## Goal
Remove external `inflector` shard dependency by vendoring the library into our project and improving it to fix known issues while maintaining 100% backward compatibility.

## Current State Analysis

### External Dependency
- **Library**: `phoffer/inflector.cr` (v0.1.8)
- **Location**: External shard in `shard.yml`
- **Usage**: Only 4 methods used from the library

### Current Usage Points
```crystal
# In src/amber_cli/core/word_transformer.cr:
Inflector.singularize(word)    # Line 122
Inflector.pluralize(word)      # Line 125  
Inflector.classify(word)       # Line 150
Inflector.foreign_key(word)    # Line 157
```

### Known Issues to Fix
1. **"foot" → "foots"** instead of "feet" (currently fixed with custom override)
2. **Potential other irregular plurals** that need investigation
3. **Performance improvements** using Crystal's built-in methods where possible

### Test Coverage
- **359 lines** of comprehensive tests in `spec/core/word_transformer_spec.cr`
- **Edge cases covered**: empty strings, single chars, irregular plurals, acronyms
- **Performance tests**: 1000 iterations for built-in methods
- **Custom conventions**: Pattern overrides and fallbacks

---

## Migration Plan

### Phase 1: Research & Analysis ✅

#### 1.1 Clone and Analyze Source Code
- [ ] Clone `phoffer/inflector.cr` repository
- [ ] Analyze source code structure and implementation
- [ ] Identify the 4 methods we actually use
- [ ] Document current irregular plurals/singulars
- [ ] Create list of known incorrect transformations

#### 1.2 Identify Improvement Opportunities  
- [ ] Compare with Rails ActiveSupport::Inflector for reference
- [ ] Research comprehensive lists of irregular English plurals
- [ ] Identify performance bottlenecks in current implementation
- [ ] Document Crystal built-in methods we can leverage

### Phase 2: Setup Vendored Library ✅

#### 2.1 Create Vendor Directory
- [ ] Create `src/amber_cli/vendor/` directory
- [ ] Create `src/amber_cli/vendor/inflector/` subdirectory
- [ ] Add appropriate README and license attribution

#### 2.2 Extract Required Code
- [ ] Copy only the required methods and dependencies
- [ ] Rename module to `AmberCLI::Vendor::Inflector`
- [ ] Remove unused methods to reduce code size
- [ ] Maintain original method signatures for compatibility

### Phase 3: Improve Implementation ✅

#### 3.1 Fix Known Issues
- [ ] Fix "foot" → "feet" (remove need for custom override)
- [ ] Add comprehensive irregular plurals list
- [ ] Fix any other documented incorrect transformations
- [ ] Add missing irregular singulars

#### 3.2 Performance Improvements
- [ ] Use Crystal's `String#camelcase` instead of custom implementation
- [ ] Use Crystal's `String#underscore` instead of custom implementation  
- [ ] Optimize regex patterns for better performance
- [ ] Add memoization for expensive operations if needed

#### 3.3 Enhanced Irregular Words Database
- [ ] Create comprehensive IRREGULAR_PLURALS hash
- [ ] Create comprehensive IRREGULAR_SINGULARS hash  
- [ ] Add common programming-related words (e.g., "schema" → "schemas")
- [ ] Include domain-specific terms relevant to web development

### Phase 4: Testing & Validation ✅

#### 4.1 Maintain Backward Compatibility
- [ ] Run existing test suite to ensure no regressions
- [ ] Create comparison tests between old and new implementations
- [ ] Document any intentional behavior changes (bug fixes)
- [ ] Ensure all 359 existing tests continue to pass

#### 4.2 Enhanced Test Coverage
- [ ] Add tests for all irregular plurals/singulars
- [ ] Add performance benchmarks
- [ ] Test edge cases with new improvements
- [ ] Add tests for previously incorrect transformations

#### 4.3 Integration Testing
- [ ] Test with real Amber CLI workflows
- [ ] Verify generator output remains consistent
- [ ] Test template generation with new inflector
- [ ] Validate naming conventions work correctly

### Phase 5: Migration & Cleanup ✅

#### 5.1 Update Dependencies
- [ ] Remove `inflector` from `shard.yml`
- [ ] Update require statements to use vendored version
- [ ] Update imports in `word_transformer.cr`
- [ ] Remove external dependency documentation

#### 5.2 Clean Up Custom Overrides
- [ ] Remove custom overrides that are now fixed in vendored version
- [ ] Simplify CUSTOM_PLURALS/CUSTOM_SINGULARS hashes
- [ ] Update comments explaining why custom overrides remain

#### 5.3 Documentation Updates
- [ ] Update README with vendored library information
- [ ] Document improvements made over original
- [ ] Add attribution to original library authors
- [ ] Document any new irregular words added

---

## Implementation Checklist

### 🔍 **Phase 1: Research & Analysis**

#### 1.1 Source Code Analysis
- [ ] `git clone https://github.com/phoffer/inflector.cr`
- [ ] Document current implementation of `pluralize` method
- [ ] Document current implementation of `singularize` method  
- [ ] Document current implementation of `classify` method
- [ ] Document current implementation of `foreign_key` method
- [ ] Create inventory of all irregular plurals in current library
- [ ] Identify performance bottlenecks and optimization opportunities

#### 1.2 Issue Research
- [ ] Research comprehensive English irregular plurals (child/children, mouse/mice, etc.)
- [ ] Research programming-specific plurals (schema/schemas vs schemata)
- [ ] Create list of words that Rails ActiveSupport handles correctly
- [ ] Document any GitHub issues in original `phoffer/inflector.cr` repo
- [ ] Test original library against comprehensive word lists

### 🏗️ **Phase 2: Setup Vendored Library**

#### 2.1 Directory Structure
- [ ] Create `src/amber_cli/vendor/inflector/`
- [ ] Create `src/amber_cli/vendor/inflector/inflector.cr` (main module)
- [ ] Create `src/amber_cli/vendor/inflector/irregular_words.cr` (word lists)
- [ ] Create `src/amber_cli/vendor/inflector/README.md` (attribution)
- [ ] Create `src/amber_cli/vendor/inflector/LICENSE` (copy original license)

#### 2.2 Code Extraction
- [ ] Copy `pluralize` method and dependencies
- [ ] Copy `singularize` method and dependencies
- [ ] Copy `classify` method and dependencies  
- [ ] Copy `foreign_key` method and dependencies
- [ ] Rename module to `AmberCLI::Vendor::Inflector`
- [ ] Remove all unused methods and constants
- [ ] Maintain identical method signatures for drop-in replacement

### ⚡ **Phase 3: Improve Implementation**

#### 3.1 Enhanced Irregular Words
- [ ] Add comprehensive irregular plurals list (appendix A of this plan)
- [ ] Add irregular singulars (reverse of plurals)
- [ ] Add programming-specific words:
  - [ ] "schema" → "schemas" (not "schemata")
  - [ ] "vertex" → "vertices" or "vertexes"
  - [ ] "index" → "indexes" (not "indices" for programming)
  - [ ] "matrix" → "matrices"
  - [ ] "datum" → "data"
- [ ] Add web development specific words:
  - [ ] "email" → "emails"  
  - [ ] "ajax" → "ajax calls"
  - [ ] "api" → "apis"

#### 3.2 Fix Known Issues
- [ ] Fix "foot" → "feet" (currently returns "foots")
- [ ] Test and fix other known incorrect transformations
- [ ] Validate against comprehensive test cases
- [ ] Compare results with Rails ActiveSupport when possible

#### 3.3 Performance Optimization
- [ ] Replace custom camel case with Crystal's `String#camelcase`
- [ ] Replace custom underscore with Crystal's `String#underscore`
- [ ] Optimize regex patterns for common cases
- [ ] Add benchmarking to measure improvements

### 🧪 **Phase 4: Testing & Validation**

#### 4.1 Backward Compatibility Testing
- [ ] Run full existing test suite: `crystal spec`
- [ ] Ensure all 359 tests pass without modification
- [ ] Create before/after comparison tests for each method
- [ ] Document any intentional behavior changes (bug fixes)

#### 4.2 Enhanced Test Coverage
- [ ] Add test for every word in irregular plurals list
- [ ] Add test for every word in irregular singulars list
- [ ] Add performance benchmarks comparing old vs new
- [ ] Add edge case tests for programming terminology
- [ ] Add tests for previously failing transformations

#### 4.3 Integration Testing
- [ ] Test `amber generate model User` (pluralization)
- [ ] Test `amber generate controller Posts` (singularization)
- [ ] Test scaffold generation with complex words
- [ ] Verify template generation still works correctly
- [ ] Test with custom naming conventions

### 🔄 **Phase 5: Migration & Cleanup**

#### 5.1 Dependency Updates
- [ ] Remove `inflector:` block from `shard.yml`
- [ ] Update `require "inflector"` to `require "./vendor/inflector/inflector"`
- [ ] Update method calls from `Inflector.` to `AmberCLI::Vendor::Inflector.`
- [ ] Test compilation: `crystal build src/amber_cli.cr`

#### 5.2 Code Cleanup
- [ ] Remove custom overrides that are now fixed:
  - [ ] Remove "foot" → "feet" from CUSTOM_PLURALS if fixed
  - [ ] Clean up any other custom overrides that are redundant
- [ ] Update comments explaining remaining custom overrides
- [ ] Simplify word_transformer.cr if possible

#### 5.3 Documentation
- [ ] Update README.md with vendored library section
- [ ] Document improvements over original library
- [ ] Add attribution: "Based on phoffer/inflector.cr"
- [ ] Update CHANGELOG with migration details
- [ ] Add documentation for new irregular words added

---

## Quality Assurance Checklist

### 📊 **Performance Requirements**
- [ ] New implementation must be ≥ same speed as original
- [ ] Built-in Crystal methods should improve performance for camelcase/underscore
- [ ] Memory usage should be equal or better
- [ ] Benchmark against 1000+ word transformations

### 🔒 **Compatibility Requirements**  
- [ ] 100% backward compatibility for all existing functionality
- [ ] All existing tests must pass without modification
- [ ] Same method signatures and return types
- [ ] Same error handling behavior

### 📈 **Improvement Requirements**
- [ ] Must fix "foot" → "feet" issue
- [ ] Must add at least 50 additional irregular plurals
- [ ] Must improve accuracy over original library
- [ ] Must maintain or improve performance

### 🧪 **Testing Requirements**
- [ ] Minimum 95% test coverage for vendored code
- [ ] All edge cases from original tests must pass
- [ ] New irregular words must have explicit tests
- [ ] Performance benchmarks must be included

---

## Appendix A: Comprehensive Irregular Plurals

### Core English Irregulars (Must Fix)
```crystal
IRREGULAR_PLURALS = {
  # Body parts
  "foot" => "feet",
  "tooth" => "teeth", 
  "goose" => "geese",

  # Animals
  "mouse" => "mice",
  "louse" => "lice",
  "ox" => "oxen",

  # People
  "child" => "children",
  "person" => "people",
  "man" => "men", 
  "woman" => "women",

  # Latin/Greek origins
  "datum" => "data",
  "genus" => "genera",
  "corpus" => "corpora",
  "opus" => "opera",

  # Special cases
  "sheep" => "sheep",
  "deer" => "deer", 
  "fish" => "fish",
  "series" => "series",
  "species" => "species",
}
```

### Programming-Specific Words
```crystal
PROGRAMMING_PLURALS = {
  "schema" => "schemas",    # Not "schemata" in programming
  "index" => "indexes",     # Not "indices" in programming  
  "vertex" => "vertices",
  "matrix" => "matrices",
  "regex" => "regexes",
  "ajax" => "ajax",
  "api" => "apis",
}
```

---

## Success Criteria

### ✅ **Migration Complete When:**
1. External `inflector` dependency removed from `shard.yml`
2. All tests pass: `crystal spec` returns 0 failures
3. CLI compiles without errors: `crystal build src/amber_cli.cr`
4. Performance equal or better than original
5. At least 5 previously incorrect words now fixed
6. Comprehensive test coverage for all new irregular words

### 🎯 **Quality Metrics:**
- **Test Coverage**: >95% for vendored inflector code
- **Performance**: ≥100% of original speed  
- **Accuracy**: ≥99% correct on standard English test cases
- **Maintainability**: Well-documented, clear code structure
- **Compatibility**: 100% backward compatible

---

## Timeline Estimate

- **Phase 1 (Research)**: 4-6 hours
- **Phase 2 (Setup)**: 2-3 hours  
- **Phase 3 (Improve)**: 6-8 hours
- **Phase 4 (Testing)**: 4-6 hours
- **Phase 5 (Migration)**: 2-3 hours

**Total**: ~18-26 hours of focused development time

---

## Risk Mitigation

### 🚨 **Potential Risks & Solutions:**

1. **Breaking Changes**
   - *Risk*: Vendored version behaves differently
   - *Solution*: Comprehensive comparison testing before migration

2. **Performance Regression**  
   - *Risk*: New implementation slower than original
   - *Solution*: Benchmark at each step, optimize hot paths

3. **Missing Edge Cases**
   - *Risk*: Original library handles cases we missed
   - *Solution*: Extract complete test suite from original library

4. **Maintenance Burden**
   - *Risk*: Now responsible for maintaining inflector code
   - *Solution*: Well-documented, simple implementation with comprehensive tests

---

This plan ensures a safe, systematic migration that improves functionality while maintaining complete backward compatibility. 