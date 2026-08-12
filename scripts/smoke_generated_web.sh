#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 /path/to/amber [framework-commit]" >&2
  exit 64
fi

cli_path="$1"
framework_commit="${2:-}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [[ "$cli_path" != /* ]]; then
  cli_path="$(cd "$(dirname "$cli_path")" && pwd)/$(basename "$cli_path")"
fi

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/amber-v2-web-smoke.XXXXXX")"
app_path="$smoke_root/amber_beta_smoke"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$smoke_root"
}
trap cleanup EXIT

"$cli_path" --version | grep -E "Amber CLI v2\.0\.[0-9]+"
"$cli_path" new "$app_path" --type web --no-deps

grep -F "github: amberframework/amber" "$app_path/shard.yml"
grep -F "version: 2.0.0-beta.4" "$app_path/shard.yml"
grep -F "github: crimson-knight/grant" "$app_path/shard.yml"
grep -F "github: amberframework/asset_pipeline" "$app_path/shard.yml"
grep -F "version: ~> 0.37.0" "$app_path/shard.yml"
grep -F "github: crystal-lang/crystal-sqlite3" "$app_path/shard.yml"
grep -F "template: ecr" "$app_path/.amber.yml"
grep -F "database: sqlite" "$app_path/.amber.yml"
grep -F "model: grant" "$app_path/.amber.yml"
test -s "$app_path/config/database.cr"
test -s "$app_path/config/assets.cr"
test -s "$app_path/public/assets/manifest.json"
test ! -e "$app_path/public/css/app.css"
test ! -e "$app_path/public/js/app.js"

if grep -Eiq 'gemma:|slang' "$app_path/shard.yml" "$app_path/.amber.yml"; then
  echo "generated app contains an unsupported beta dependency or template" >&2
  exit 1
fi

if [[ -n "$framework_commit" ]]; then
  sed -i.bak -E "s/    version: 2\.0\.0-beta\.[0-9]+/    commit: ${framework_commit}/" "$app_path/shard.yml"
  rm -f "$app_path/shard.yml.bak"
fi

cd "$app_path"
"$cli_path" assets check
env GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=core.hooksPath \
  GIT_CONFIG_VALUE_0=/dev/null \
  shards install
"$cli_path" assets build
"$cli_path" assets check
crystal spec

"$cli_path" generate scaffold Pet name:string:required species:string:required adopted:bool
"$cli_path" generate job PublishPost --queue=default
"$cli_path" generate mailer Digest --actions=weekly
"$cli_path" generate channel Updates --topics=posts
"$cli_path" generate migration CreatePosts

grep -F "class Pet < Grant::Base" src/models/pet.cr
grep -F -- "-- +micrate Up" db/migrations/*_create_pets.sql
grep -F -- "-- +micrate Down" db/migrations/*_create_pets.sql
grep -F 'resources "/pets", PetController' config/routes.cr
grep -F 'render(partial: "_form.ecr")' src/views/pet/new.ecr
grep -F 'hidden_field("_method", "PATCH")' src/views/pet/_form.ecr

AMBER_ENV=test "$cli_path" database migrate
AMBER_ENV=test "$cli_path" database status | grep -F "Applied At"
"$cli_path" database migrate

if find src spec -iname '*slang*' -print | grep -q .; then
  echo "a core generator emitted a Slang file" >&2
  exit 1
fi
crystal tool format --check src spec
crystal spec
"$cli_path" assets build
"$cli_path" assets check
crystal build src/amber_beta_smoke.cr -o bin/amber_beta_smoke

asset_paths="$(crystal run "$script_dir/read_asset_paths.cr" -- \
  public/assets/manifest.json \
  stylesheets/app.css \
  javascript/app.js \
  images/amber-crystal.svg \
  images/favicon.svg)"
css_url="$(printf '%s\n' "$asset_paths" | sed -n '1p')"
js_url="$(printf '%s\n' "$asset_paths" | sed -n '2p')"
logo_url="$(printf '%s\n' "$asset_paths" | sed -n '3p')"
favicon_url="$(printf '%s\n' "$asset_paths" | sed -n '4p')"
test -n "$css_url"
test -n "$js_url"
test -n "$logo_url"
test -n "$favicon_url"
grep -F "$logo_url" "public/${css_url#/}"

AMBER_SERVER_PORT=3210 ./bin/amber_beta_smoke >server.log 2>&1 &
server_pid="$!"

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:3210/ >homepage.html; then
    break
  fi
  sleep 1
done

curl --fail --silent http://127.0.0.1:3210/ | grep -F "Your new idea"
curl --fail --silent http://127.0.0.1:3210/ | grep -F "Ready to customize"
curl --fail --silent http://127.0.0.1:3210/ | grep -F 'type="importmap"'
curl --fail --silent http://127.0.0.1:3210/ | grep -F "$css_url"
curl --fail --silent http://127.0.0.1:3210/ | grep -F "$js_url"
curl --fail --silent http://127.0.0.1:3210/ | grep -F "$logo_url"
curl --fail --silent http://127.0.0.1:3210/ | grep -F "$favicon_url"
curl --fail --silent http://127.0.0.1:3210/ | grep -F 'integrity="sha256-'

css_headers="$smoke_root/css-headers.txt"
css_body="$smoke_root/css-body.css"
curl --fail --silent --dump-header "$css_headers" --output "$css_body" "http://127.0.0.1:3210$css_url"
grep -F "Amber V2 starter styles" "$css_body"
grep -F -- "--amber-accent: #e96918" "$css_body"
grep -i -F "Content-Type: text/css" "$css_headers"
grep -i -F "Cache-Control: public, max-age=31536000, immutable" "$css_headers"
grep -i -F "X-Content-Type-Options: nosniff" "$css_headers"

gzip_headers="$smoke_root/css-gzip-headers.txt"
curl --fail --silent --header "Accept-Encoding: gzip" --dump-header "$gzip_headers" --output /dev/null "http://127.0.0.1:3210$css_url"
grep -i -F "Content-Encoding: gzip" "$gzip_headers"
grep -i -F "Content-Type: text/css" "$gzip_headers"
grep -i -F "Vary: Accept-Encoding" "$gzip_headers"

js_headers="$smoke_root/js-headers.txt"
curl --fail --silent --dump-header "$js_headers" "http://127.0.0.1:3210$js_url" | grep -F 'dataset.javascript = "ready"'
grep -i -E "Content-Type: (text/javascript|application/javascript)" "$js_headers"
grep -i -F "Cache-Control: public, max-age=31536000, immutable" "$js_headers"

image_headers="$smoke_root/image-headers.txt"
curl --fail --silent --dump-header "$image_headers" "http://127.0.0.1:3210$logo_url" | grep -F "<svg"
grep -i -F "Content-Type: image/svg+xml" "$image_headers"
grep -i -F "Cache-Control: public, max-age=31536000, immutable" "$image_headers"

new_page="$smoke_root/new-pet.html"
edit_page="$smoke_root/edit-pet.html"
cookie_jar="$smoke_root/cookies.txt"
response_headers="$smoke_root/response-headers.txt"

curl --fail --silent --cookie-jar "$cookie_jar" http://127.0.0.1:3210/pets/new >"$new_page"
test "$(grep -c '<!DOCTYPE html>' "$new_page")" -eq 1
grep -F 'form action="/pets" method="POST"' "$new_page"
grep -F 'name="adopted"' "$new_page" | grep -F 'value="true"'
csrf_token="$(sed -n 's/.*name="_csrf" value="\([^"]*\)".*/\1/p' "$new_page" | head -1)"
test -n "$csrf_token"

curl --fail --silent --output /dev/null --dump-header "$response_headers" \
  --cookie "$cookie_jar" --request POST \
  --data-urlencode "_csrf=$csrf_token" \
  --data-urlencode "name=Ruby" \
  --data-urlencode "species=Dog" \
  http://127.0.0.1:3210/pets
grep -F "Location: /pets/1" "$response_headers"
curl --fail --silent http://127.0.0.1:3210/pets/1 | grep -F "Ruby"

curl --fail --silent --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
  http://127.0.0.1:3210/pets/1/edit >"$edit_page"
grep -F 'form action="/pets/1" method="POST"' "$edit_page"
grep -F 'name="_method"' "$edit_page" | grep -F 'value="PATCH"'
csrf_token="$(sed -n 's/.*name="_csrf" value="\([^"]*\)".*/\1/p' "$edit_page" | head -1)"
test -n "$csrf_token"

curl --fail --silent --output /dev/null --dump-header "$response_headers" \
  --cookie "$cookie_jar" --request POST \
  --data-urlencode "_csrf=$csrf_token" \
  --data-urlencode "_method=PATCH" \
  --data-urlencode "name=Ruby II" \
  --data-urlencode "species=Dog" \
  --data-urlencode "adopted=true" \
  http://127.0.0.1:3210/pets/1
grep -F "Location: /pets/1" "$response_headers"
curl --fail --silent http://127.0.0.1:3210/pets/1 | grep -F "Ruby II"

kill "$server_pid"
wait "$server_pid" || true
server_pid=""

echo "Amber V2 beta web-app smoke test passed"
