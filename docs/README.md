# Amber CLI Documentation

This directory contains the generated HTML documentation for the Amber CLI.

## Automatic Generation

The documentation is automatically generated using Crystal's built-in `crystal docs` command and published to GitHub Pages via GitHub Actions.

## Manual Generation

To generate the documentation locally:

```bash
# Install dependencies
shards install

# Generate documentation
crystal docs \
  --project-name="Amber CLI" \
  --project-version="$(git describe --tags --always)" \
  --source-url-pattern="https://github.com/amberframework/amber_cli/blob/%{refname}/%{path}#L%{line}" \
  --output=docs \
  --format=html \
  --sitemap-base-url="https://amberframework.github.io/amber_cli/"

# Serve locally (optional)
cd docs && python -m http.server 8000
```

## Documentation Structure

The documentation is generated from:

- **Code comments** - Crystal docstrings throughout the codebase
- **Documentation module** - Comprehensive guides in `src/amber_cli/documentation.cr`
- **Examples** - Inline code examples and usage patterns
- **API references** - Automatically extracted from class and method definitions

## Publishing

Documentation is automatically published to: https://amberframework.github.io/amber_cli/

The publishing process:
1. Triggered on pushes to the `main` branch
2. Generates fresh documentation using `crystal docs`
3. Uploads to GitHub Pages
4. Updates the live site within minutes

## Contributing to Documentation

To improve the documentation:

1. **Add docstrings** to classes and methods using Crystal's documentation format
2. **Update the documentation module** in `src/amber_cli/documentation.cr`
3. **Include examples** in code comments using Crystal's documentation conventions
4. **Test locally** by generating docs before submitting PRs

For more information about Crystal documentation conventions, see:
https://crystal-lang.org/reference/1.16/syntax_and_semantics/documenting_code.html 