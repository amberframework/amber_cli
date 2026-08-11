#!/usr/bin/env bash
set -euo pipefail

shard_version="$(awk '/^version:/ { print $2; exit }' shard.yml)"
cli_version="$(sed -n 's/.*VERSION = "\([^"]*\)".*/\1/p' src/amber_cli.cr | head -1)"
test "$shard_version" = "2.0.4"
test "$cli_version" = "$shard_version"

grep -F 'github: amberframework/amber' src/amber_cli/commands/new.cr
grep -F 'version: 2.0.0-beta.3' src/amber_cli/commands/new.cr
grep -F 'template: ecr' src/amber_cli/commands/new.cr
grep -F 'model: grant' src/amber_cli/commands/new.cr
grep -F 'database: #{database}' src/amber_cli/commands/new.cr
grep -F 'github: crimson-knight/grant' src/amber_cli/commands/new.cr
grep -F 'github: amberframework/micrate' shard.yml
test -s src/amber_cli/templates/app/config/database.cr.ecr
grep -F 'Your new idea' src/amber_cli/commands/new.cr
grep -F -- '--amber-accent: #e96918' src/amber_cli/commands/new.cr
grep -F 'Your new idea' src/amber_cli/templates/app/src/views/home/index.ecr.ecr
test -s src/amber_cli/templates/app/public/css/app.css
test -s src/amber_cli/templates/app/public/js/app.js
grep -F 'brew install amberframework/amber_cli/amber_cli' README.md

files=(
  README.md
  RELEASE_NOTES_V2.0.3.md
  RELEASE_NOTES_V2.0.4.md
  RELEASE_SETUP.md
  .github/ISSUE_TEMPLATE/release-checklist.md
  docs/*.md
)

if grep -Ein 'amberframework/amber-cli|brew tap amberframework/amber_cli|brew install amber-cli|brew install amber_cli|docs\.amberframework\.org' "${files[@]}" src/amber_cli/*.cr src/amber_cli/commands/*.cr; then
  echo "Amber CLI docs contain an untrusted or incomplete Homebrew install path" >&2
  exit 1
fi

if grep -Eir 'crimson-knight/(amber|gemma)' src/amber_cli/templates/app src/amber_cli/commands/new.cr; then
  echo "supported web template contains a personal Amber or Gemma dependency" >&2
  exit 1
fi

if find src/amber_cli/templates/app -iname '*slang*' -print | grep -q .; then
  echo "supported web template still contains a Slang template" >&2
  exit 1
fi

echo "Amber CLI beta contract checks passed"
