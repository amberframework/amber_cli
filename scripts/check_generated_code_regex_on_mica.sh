#!/usr/bin/env bash
# Checks every regex in the code `amber new` and `amber generate` write
# against Mica's dialect (see scripts/check_regex_on_mica.sh).
#
# The generator templates are ECR, so their regexes can only be read after
# they are rendered. This script renders them: one web app per database
# (sqlite, pg, mysql) with every generator run in it, and one native app.
# It then checks the Crystal each app holds. The shards an app depends on
# are checked in their own repositories.
#
# usage: scripts/check_generated_code_regex_on_mica.sh /path/to/amber [OUTPUT_DIR]
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 /path/to/amber [output-directory]" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
cli_path="$1"
if [[ "$cli_path" != /* ]]; then
  cli_path="$(cd "$(dirname "$cli_path")" && pwd)/$(basename "$cli_path")"
fi
output_directory="${2:-${TMPDIR:-/tmp}/amber-generated-code-regex}"

rm -rf "$output_directory"
mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"

generate_web_app() {
  local database="$1"
  local app_path="$output_directory/regex_probe_$database"
  (
    cd "$output_directory"
    "$cli_path" new "regex_probe_$database" -d "$database" -y --no-deps --skip-agent-setup >/dev/null
    cd "$app_path"
    "$cli_path" generate scaffold Author first_name:string email:email >/dev/null
    "$cli_path" generate scaffold Post title:string body:text published:bool author:reference >/dev/null
    "$cli_path" generate model Comment body:text post:reference >/dev/null
    "$cli_path" generate controller Pages index show >/dev/null
    "$cli_path" generate migration AddStatusToPosts >/dev/null
    "$cli_path" generate mailer Author --actions=welcome,notify >/dev/null
    "$cli_path" generate job SendDigest --queue=mailers >/dev/null
    "$cli_path" generate schema Signup first_name:string email:string:required age:int32 >/dev/null
    "$cli_path" generate channel Chat >/dev/null
    "$cli_path" generate api Product title:string price:float >/dev/null
    "$cli_path" generate auth User >/dev/null
  )
  test -f "$app_path/src/models/post.cr"
  test -f "$app_path/src/controllers/api/product_controller.cr"
}

for database in sqlite pg mysql; do
  generate_web_app "$database"
done
(cd "$output_directory" && "$cli_path" new regex_probe_native --type native -y --no-deps --skip-agent-setup >/dev/null)
test -f "$output_directory/regex_probe_native/shard.yml"

cd "$script_dir/.."
scripts/check_regex_on_mica.sh "$output_directory"
