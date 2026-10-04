#!/bin/bash

# Amber CLI Documentation Generator
# This script generates the project documentation using Crystal's built-in docs command

set -e

echo "🔧 Amber CLI Documentation Generator"
echo "======================================"

# Check if Crystal is installed
if ! command -v crystal &> /dev/null; then
    echo "❌ Crystal is not installed. Please install Crystal first."
    echo "   Visit: https://crystal-lang.org/install/"
    exit 1
fi

# Check if we're in the project root
if [ ! -f "shard.yml" ]; then
    echo "❌ This script must be run from the project root directory"
    exit 1
fi

echo "📦 Installing dependencies..."
minecart install --frozen

echo "📖 Generating documentation..."

# Get version from git or use main
VERSION=$(git describe --tags --always 2>/dev/null || echo "main")

# Generate documentation
crystal docs \
  --project-name="Amber CLI" \
  --project-version="$VERSION" \
  --source-url-pattern="https://github.com/amberframework/amber_cli/blob/%{refname}/%{path}#L%{line}" \
  --output=docs \
  --format=html \
  --sitemap-base-url="https://amberframework.github.io/amber_cli/" \
  --canonical-base-url="https://amberframework.github.io/amber_cli/"

echo "✅ Documentation generated successfully in ./docs"
echo ""
echo "🎉 Done! Documentation is ready."
echo "   Local files: ./docs/index.html"
echo "   Live site: https://amberframework.github.io/amber_cli/"
