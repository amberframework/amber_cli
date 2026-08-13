#!/usr/bin/env bash
set -euo pipefail

shard_version="$(awk '/^version:/ { print $2; exit }' shard.yml)"
cli_version="$(sed -n 's/.*VERSION = "\([^"]*\)".*/\1/p' src/amber_cli.cr | head -1)"
test "$shard_version" = "2.0.6"
test "$cli_version" = "$shard_version"

grep -F 'github: amberframework/amber' src/amber_cli/commands/new.cr
grep -F 'version: 2.0.0-beta.5' src/amber_cli/commands/new.cr
grep -F 'template: ecr' src/amber_cli/commands/new.cr
grep -F 'model: grant' src/amber_cli/commands/new.cr
grep -F 'database: #{database}' src/amber_cli/commands/new.cr
grep -F 'github: crimson-knight/grant' src/amber_cli/commands/new.cr
grep -F 'github: amberframework/asset_pipeline' src/amber_cli/commands/new.cr
grep -F 'version: ~> 0.37.0' src/amber_cli/commands/new.cr
grep -F 'github: amberframework/asset_pipeline' src/amber_cli/templates/app/shard.yml.ecr
grep -F 'version: ~> 0.37.0' src/amber_cli/templates/app/shard.yml.ecr
grep -F 'github: amberframework/amber' src/amber_cli/generators/native_app.cr
grep -F 'version: 2.0.0-beta.5' src/amber_cli/generators/native_app.cr
grep -F 'version: ~> 0.37.0' src/amber_cli/generators/native_app.cr
if grep -F 'branch:' src/amber_cli/generators/native_app.cr; then
  echo "native app template contains a mutable dependency branch" >&2
  exit 1
fi
if grep -F 'shards install || true' src/amber_cli/generators/native_app.cr; then
  echo "native app setup masks dependency installation failures" >&2
  exit 1
fi
grep -F 'github: amberframework/micrate' shard.yml
grep -F 'info "  2. Bind it in a controller: schema :create, #{class_name}Schema"' src/amber_cli/commands/generate.cr
grep -F 'content_type "#{content_type}"' src/amber_cli/commands/generate.cr
grep -F 'schema :create, #{class_name}Schema' src/amber_cli/commands/generate.cr
grep -F 'schema :update, #{class_name}Schema' src/amber_cli/commands/generate.cr
grep -F 'schema = validated_as(#{class_name}Schema)' src/amber_cli/commands/generate.cr
grep -F 'protected def handle_schema_validation_failure(' src/amber_cli/commands/generate.cr
if grep -F '#   schema = #{class_name}Schema.new(data)' src/amber_cli/commands/generate.cr; then
  echo "schema generator still teaches direct construction as the controller path" >&2
  exit 1
fi

grep -F 'scripts/smoke_generated_web.sh ./amber' .github/workflows/release.yml
if grep -R -F 'AMBER_CANDIDATE_FRAMEWORK' .github/workflows; then
  echo "CI workflows must test the published framework emitted by the template" >&2
  exit 1
fi
grep -F '[string]$FrameworkRepository = "amberframework/amber"' scripts/smoke_generated_web.ps1
grep -F '"    github: $FrameworkRepository"' scripts/smoke_generated_web.ps1
test -s src/amber_cli/templates/app/config/database.cr.ecr
test -s src/amber_cli/templates/app/config/assets.cr.ecr
grep -F 'Your new idea' src/amber_cli/commands/new.cr
grep -F -- '--amber-accent: #e96918' src/amber_cli/commands/new.cr
grep -F 'Your new idea' src/amber_cli/templates/app/src/views/home/index.ecr.ecr
test -s src/amber_cli/templates/app/app/assets/stylesheets/app.css
test -s src/amber_cli/templates/app/app/assets/javascript/app.js
test -s src/amber_cli/templates/app/app/assets/images/amber-crystal.svg
test -s src/amber_cli/templates/app/app/assets/images/favicon.svg
test ! -e src/amber_cli/templates/app/public/css/app.css
test ! -e src/amber_cli/templates/app/public/js/app.js
grep -F 'url("../images/amber-crystal.svg")' src/amber_cli/templates/app/app/assets/stylesheets/app.css
grep -F 'stylesheet_link_tag("stylesheets/app.css")' src/amber_cli/templates/app/src/views/layouts/application.ecr.ecr
grep -F 'javascript_importmap_tag({"app" => "javascript/app.js"}' src/amber_cli/templates/app/src/views/layouts/application.ecr.ecr
grep -F 'favicon_tag("images/favicon.svg")' src/amber_cli/templates/app/src/views/layouts/application.ecr.ecr
grep -F 'image_tag("images/amber-crystal.svg"' src/amber_cli/templates/app/src/views/home/index.ecr.ecr
grep -F '/public/assets/' src/amber_cli/templates/app/.gitignore.ecr
grep -F 'brew install amberframework/amber_cli/amber_cli' README.md

files=(
  README.md
  RELEASE_NOTES_V2.0.3.md
  RELEASE_NOTES_V2.0.4.md
  RELEASE_NOTES_V2.0.6.md
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
