# Amber CLI Test Suite

This comprehensive test suite is designed to thoroughly validate the new Amber CLI architecture that uses only Crystal's standard library.

## Test Organization

### Core Component Tests (`spec/core/`)

#### `word_transformer_spec.cr`
Tests the fundamental word transformation engine that powers naming conventions:
- **Basic transformations**: singular, plural, camel_case, snake_case, etc.
- **Custom naming patterns**: Rails-like conventions, enterprise patterns
- **Edge cases**: empty strings, single characters, special characters
- **Custom transformation patterns**: Using template variables for naming

#### `generator_config_spec.cr`
Tests configuration loading and validation:
- **JSON configuration loading**: Basic and complex configurations
- **YAML configuration loading**: Multi-format support
- **Error handling**: Invalid files, malformed JSON/YAML, missing files
- **Type conversion**: JSON::Any to String conversion
- **Minimal configurations**: Testing with only required fields

#### `template_engine_spec.cr`
Tests template processing and file generation:
- **Placeholder replacement**: Simple and complex scenarios
- **Strict vs non-strict mode**: Handling unknown placeholders
- **File generation from rules**: Complete workflow testing
- **Conditional generation**: Rules with conditions
- **Multiple transformations**: Complex template scenarios
- **Error handling**: Missing templates, invalid syntax

### Command System Tests (`spec/commands/`)

#### `base_command_spec.cr`
Tests the command system architecture:
- **Command initialization**: Basic setup and configuration
- **Argument parsing**: Using Crystal's OptionParser
- **Option handling**: Flags, values, mixed options
- **Help system**: Banner and option descriptions
- **Command registry**: Registration and execution
- **Error handling**: Invalid options, missing commands

### Integration Tests (`spec/integration/`)

#### `generator_manager_spec.cr`
Tests the complete generator workflow:
- **Single file generation**: Basic model/controller generation
- **Multi-file generation**: Scaffold-like functionality
- **Template variables**: Custom project-wide variables
- **Conditional generation**: Rules based on configuration
- **Custom transformations**: Naming convention application
- **Complex scenarios**: Nested directories, multiple transformations
- **Error scenarios**: Missing templates, invalid generators

## Test Strategy

### 1. Unit Testing
Each component is tested in isolation with comprehensive coverage of:
- Normal operation paths
- Edge cases and boundary conditions
- Error conditions and recovery
- Type safety and validation

### 2. Integration Testing
Tests verify that components work together correctly:
- Configuration loading → Template processing → File generation
- Command parsing → Generator execution → File output
- Template variables → Word transformations → Final output

### 3. Real-World Scenarios
Tests simulate actual usage patterns:
- **Rails-like conventions**: Standard web framework patterns
- **Enterprise patterns**: Complex namespaced architectures
- **API-only applications**: Minimal, focused generation
- **Custom project structures**: User-defined layouts

### 4. Error Handling
Comprehensive error scenario testing:
- Graceful failure for missing files
- Clear error messages for invalid configurations
- Recovery from partial failures
- Validation of user input

## Key Test Features

### Template Directory Management
The `SpecHelper` module provides utilities for:
- Creating temporary test environments
- Setting up configuration files
- Creating template files
- Cleaning up after tests

### Fixture Data
Tests use realistic configuration examples:
- Rails-style naming conventions
- Enterprise service architectures
- API endpoint patterns
- Database migration patterns

### Assertion Patterns
Tests verify:
- File creation and content
- Directory structure generation
- Template variable substitution
- Transformation accuracy
- Error message content

## Running Tests

```bash
# Run all tests
crystal spec

# Run specific test categories
crystal spec spec/core/
crystal spec spec/commands/
crystal spec spec/integration/

# Run specific test files
crystal spec spec/core/word_transformer_spec.cr
crystal spec spec/integration/generator_manager_spec.cr

# Run with verbose output
crystal spec --verbose
```

## Test Coverage Goals

### Functional Coverage
- ✅ All transformation types (singular, plural, case conversions)
- ✅ All configuration formats (JSON, YAML)
- ✅ All generator scenarios (single file, multi-file, conditional)
- ✅ All command patterns (flags, arguments, help)

### Error Coverage
- ✅ Invalid configurations
- ✅ Missing templates
- ✅ Malformed input
- ✅ File system errors

### Edge Case Coverage
- ✅ Empty inputs
- ✅ Special characters
- ✅ Nested directories
- ✅ Complex naming patterns

### Integration Coverage
- ✅ End-to-end workflows
- ✅ Multi-component interaction
- ✅ Real-world usage patterns
- ✅ Performance considerations

## Adding New Tests

When adding functionality to the Amber CLI:

1. **Write specs first** - Follow TDD principles
2. **Test edge cases** - Don't just test the happy path
3. **Use realistic data** - Templates and configurations should be practical
4. **Test error paths** - Ensure graceful failure handling
5. **Update integration tests** - Verify component interaction

### Example Test Structure

```crystal
describe "NewFeature" do
  context "with valid input" do
    it "produces expected output" do
      # Test implementation
    end
  end

  context "with edge cases" do
    it "handles empty input" do
      # Edge case testing
    end
  end

  context "error conditions" do
    it "fails gracefully for invalid input" do
      # Error testing
    end
  end
end
```

This test suite ensures the new Amber CLI architecture is robust, reliable, and ready for production use while maintaining zero external dependencies. 