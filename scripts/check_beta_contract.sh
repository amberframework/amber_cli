#!/usr/bin/env bash
set -euo pipefail

shard_version="$(awk '/^version:/ { print $2; exit }' shard.yml)"
cli_version="$(sed -n 's/.*VERSION = "\([^"]*\)".*/\1/p' src/amber_cli.cr | head -1)"
test "$shard_version" = "2.0.2"
test "$cli_version" = "$shard_version"

grep -F 'github: amberframework/amber' src/amber_cli/commands/new.cr
grep -F 'version: 2.0.0-beta.2' src/amber_cli/commands/new.cr
grep -F 'template: ecr' src/amber_cli/commands/new.cr
grep -F 'brew tap amberframework/amber_cli' README.md
grep -F 'brew install amber_cli' README.md

if grep -Eir 'crimson-knight/(amber|grant|gemma)' src/amber_cli/templates/app src/amber_cli/commands/new.cr; then
  echo "supported web template contains a personal dependency" >&2
  exit 1
fi

if find src/amber_cli/templates/app -iname '*slang*' -print | grep -q .; then
  echo "supported web template still contains a Slang template" >&2
  exit 1
fi

echo "Amber CLI beta contract checks passed"
