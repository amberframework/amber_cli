#!/usr/bin/env bash
set -euo pipefail

shard_version="$(awk '/^version:/ { print $2; exit }' shard.yml)"
cli_version="$(sed -n 's/.*VERSION = "\([^"]*\)".*/\1/p' src/amber_cli.cr | head -1)"
test "$shard_version" = "2.0.16"
test "$cli_version" = "$shard_version"

grep -F 'github: amberframework/amber' src/amber_cli/commands/new_command.cr
grep -F 'commit: #{AmberRelease::COMMIT} # v#{AmberRelease::VERSION}' src/amber_cli/commands/new_command.cr
grep -F 'COMMIT  = "0830e3fdbc5e05be851c3c7ae7bf03b67be10732"' src/amber_cli/amber_release.cr
grep -F 'TREE    = "5709f265e0d9e942507d5d7e155a922013b65559"' src/amber_cli/amber_release.cr
grep -F 'CHECKSUM = "sha256-v2:14df1ff766414599f53a8be6816023374ba01cc6a2bd6d61ad1cabb81d88ad28"' src/amber_cli/amber_release.cr
grep -F 'template: ecr' src/amber_cli/commands/new_command.cr
grep -F 'model: grant' src/amber_cli/commands/new_command.cr
grep -F 'database: #{database}' src/amber_cli/commands/new_command.cr
grep -F 'github: crimson-knight/grant' src/amber_cli/commands/new_command.cr
grep -F 'github: amberframework/asset_pipeline' src/amber_cli/commands/new_command.cr
grep -F 'commit: #{GrantRelease::COMMIT} # v#{GrantRelease::VERSION}' src/amber_cli/commands/new_command.cr
grep -F 'commit: #{AssetPipelineRelease::COMMIT} # v#{AssetPipelineRelease::VERSION}' src/amber_cli/commands/new_command.cr
grep -F 'COMMIT   = "b83a82f0261509d4ce1f26fadb318c8ba132a066"' src/amber_cli/pinned_releases.cr
grep -F 'CHECKSUM = "sha256-v2:886b86c249fa5f7ec3d4b66a0f700d8647687b3b9984b7f580cbc2c75b5306b9"' src/amber_cli/pinned_releases.cr
grep -F 'COMMIT   = "84f3188239e43dc6e0bcfd2e72074e8ec67156cd"' src/amber_cli/pinned_releases.cr
grep -F 'CHECKSUM = "sha256-v2:137195ff733af93d36787d4a965a1846bb4795347a6eced8a5dd3f015ee729b9"' src/amber_cli/pinned_releases.cr
grep -F 'commit: b83a82f0261509d4ce1f26fadb318c8ba132a066 # v0.26.0' src/amber_cli/templates/app/shard.yml.ecr
grep -F 'github: amberframework/asset_pipeline' src/amber_cli/templates/app/shard.yml.ecr
grep -F 'commit: 84f3188239e43dc6e0bcfd2e72074e8ec67156cd # v0.40.0' src/amber_cli/templates/app/shard.yml.ecr
grep -F 'github: amberframework/amber' src/amber_cli/generators/native_app.cr
grep -F 'commit: 0830e3fdbc5e05be851c3c7ae7bf03b67be10732 # v2.0.0-beta.15' src/amber_cli/generators/native_app.cr
grep -F 'version: ~> 0.37.1' src/amber_cli/generators/native_app.cr
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
test -x scripts/check_generated_app_linkage.sh
grep -F 'scripts/check_generated_app_linkage.sh ./amber' .github/workflows/ci.yml
if grep -R -F 'AMBER_CANDIDATE_FRAMEWORK' .github/workflows; then
  echo "CI workflows must test the published framework emitted by the template" >&2
  exit 1
fi
grep -F '[string]$FrameworkRepository = "amberframework/amber"' scripts/smoke_generated_web.ps1
grep -F '"    github: $FrameworkRepository"' scripts/smoke_generated_web.ps1
test -s src/amber_cli/templates/app/config/database.cr.ecr
test -s src/amber_cli/templates/app/config/assets.cr.ecr
grep -F 'Your new idea' src/amber_cli/commands/new_command.cr
grep -F -- '--amber-accent: #e96918' src/amber_cli/commands/new_command.cr
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
grep -F 'brew trust --tap amberframework/amber_cli' README.md
grep -F 'HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli' README.md

files=(
  README.md
  RELEASE_NOTES_V2.0.3.md
  RELEASE_NOTES_V2.0.4.md
  RELEASE_NOTES_V2.0.6.md
  RELEASE_SETUP.md
  .github/ISSUE_TEMPLATE/release-checklist.md
  docs/*.md
)

if grep -Ein 'amberframework/amber-cli|brew install amber-cli|brew install amber_cli|docs\.amberframework\.org' "${files[@]}" src/amber_cli/*.cr src/amber_cli/commands/*.cr; then
  echo "Amber CLI docs contain an untrusted or incomplete Homebrew install path" >&2
  exit 1
fi

if grep -Eir 'crimson-knight/(amber|gemma)' src/amber_cli/templates/app src/amber_cli/commands/new_command.cr; then
  echo "supported web template contains a personal Amber or Gemma dependency" >&2
  exit 1
fi

if find src/amber_cli/templates/app -iname '*slang*' -print | grep -q .; then
  echo "supported web template still contains a Slang template" >&2
  exit 1
fi

echo "Amber CLI beta contract checks passed"
