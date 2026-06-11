# AI Agent Guidelines for Amber CLI

Welcome, fellow agents! When working on the `amber_cli` project, please adhere to the following principles to ensure high-quality and safe contributions:

- **This is Crystal, not Ruby.** Do not use Ruby-isms or dynamic meta-programming hacks. Respect the type system and compiled nature of Crystal.
- **Always run `ameba`** to verify linting and formatting before committing. Code should conform to the standard style.
- **Always run `crystal spec`** to ensure tests pass. No PR should break the test suite.
- **Avoid unsafe `.not_nil!` assertions.** Use proper type narrowing (e.g., `if let`, `.try`, `.as?`) to handle `nil` values gracefully.
- **Prefer modern Crystal 1.20 features and modern Process API (RFC 0025)** instead of `shell: true` when spawning external commands. Ensure determinism and security.
- **Do not use deprecated `yaml_mapping` or `json_mapping`.** Use `YAML::Serializable` and `JSON::Serializable` instead.

By following these rules, we maintain robust, readable, and idiomatic Crystal code. Let's build a great CLI together!
