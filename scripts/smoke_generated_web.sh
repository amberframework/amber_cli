#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: $0 /path/to/amber [framework-commit] [framework-repository]" >&2
  exit 64
fi

cli_path="$1"
framework_commit="${2:-}"
framework_repository="${3:-amberframework/amber}"
command -v minecart >/dev/null 2>&1 || { echo "Minecart is required for the generated web smoke" >&2; exit 1; }
if command -v crystal-alpha >/dev/null 2>&1; then
  crystal_command="crystal-alpha"
else
  crystal_command="crystal"
fi
echo "Using dependency installer: $(command -v minecart)"
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
"$cli_path" new "$app_path" --type web
test -s "$app_path/shard.lock"

grep -F 'minecart install --frozen' "$app_path/README.md"
grep -F 'crystal spec' "$app_path/README.md"
grep -F 'sha256-v2:' "$app_path/README.md"
! grep -F 'crystal-alpha' "$app_path/.amber.yml"
grep -F 'AMBER_ENV=test crystal spec' "$script_dir/../src/amber_cli/templates/app/.amber.yml.ecr"
! grep -F 'crystal-alpha' "$script_dir/../src/amber_cli/templates/app/.amber.yml.ecr"

grep -F "github: amberframework/amber" "$app_path/shard.yml"
grep -F "commit: e5c4ac7f0c1d908c3f3ad9ea4f33d858e1f47a5f # v2.0.0-beta.16" "$app_path/shard.yml"
grep -F "github: crimson-knight/grant" "$app_path/shard.yml"
grep -F "github: amberframework/asset_pipeline" "$app_path/shard.yml"
grep -F "commit: dc2185094f4da66062e4e7fb65fb41a9e46a1287 # v0.40.1" "$app_path/shard.yml"
grep -F "commit: bf9cb490695860b08f209989be686a0eb42c1019" "$app_path/shard.yml"
! grep -F "crystal-sqlite3" "$app_path/shard.yml"
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
  sed -i.bak -E "s#    github: amberframework/amber#    github: ${framework_repository}#" "$app_path/shard.yml"
  sed -i.bak -E "s/    commit: e5c4ac7f0c1d908c3f3ad9ea4f33d858e1f47a5f( # [^#]+)?$/    commit: ${framework_commit}/" "$app_path/shard.yml"
  rm -f "$app_path/shard.yml.bak"
fi

cd "$app_path"
test -s shard.lock
test -s .claude/CLAUDE.md
assistant_kib="$(du -sk .claude | awk '{print $1}')"
test "$assistant_kib" -lt 10240
grep -F 'require_exact: true' .minecart-policy.yml
! grep -F "shard.lock" .gitignore
"$cli_path" assets check
if [[ -n "$framework_commit" ]]; then
  minecart install --strict-pinning
else
  minecart install --frozen
fi
test -s shard.lock
grep -F "version: 0.28.0+git.commit.bf9cb490695860b08f209989be686a0eb42c1019" shard.lock
grep -A3 '^  grant:$' shard.lock | grep -qE '^    checksum: (sha256-v2:b736ee17d0fdce23740bd768089085ecb776b3f8ae308cd058132aff25fa4c77|git-tree:17ddebfc2afb76051b13ab46c218fd605487f52c)$'
grep -F "version: 0.40.1+git.commit.dc2185094f4da66062e4e7fb65fb41a9e46a1287" shard.lock
grep -A3 '^  asset_pipeline:$' shard.lock | grep -qE '^    checksum: (sha256-v2:ce5ff984b86dcdcedd3cbd51aab51e1b59be52273c29a18e69dc30015b8bf50e|git-tree:2ba60af749a7a1250a3a770b67230f57b31c02ef)$'
grep -F "version: 0.14.0" shard.lock
# Each shard entry carries exactly one checksum.
awk '
  /^  [[:alnum:]_-]+:$/ { if (entries > 0 && checksums != 1) bad = 1; entries++; checksums = 0; next }
  /^    checksum: sha256-v2:[0-9a-f]{64}$/ { checksums++ }
  END { if (entries == 0 || checksums != 1 || bad) exit 1 }
' shard.lock
# The Amber entry is the repository and commit this run asked for.
amber_entry="$(awk '/^  amber:$/ { inside = 1; next } inside && /^    / { print; next } inside { exit }' shard.lock)"
if [[ -n "$framework_commit" ]]; then
  expected_amber_commit="$framework_commit"
  expected_amber_git="https://github.com/${framework_repository}.git"
else
  expected_amber_commit="e5c4ac7f0c1d908c3f3ad9ea4f33d858e1f47a5f"
  expected_amber_git="https://github.com/amberframework/amber.git"
fi
grep -qxF "    git: ${expected_amber_git}" <<<"$amber_entry"
grep -qE "^    version: [^ ]+\+git\.commit\.${expected_amber_commit}$" <<<"$amber_entry"
if [[ -z "$framework_commit" ]]; then
  grep -qxF "    version: 2.0.0-beta.16+git.commit.e5c4ac7f0c1d908c3f3ad9ea4f33d858e1f47a5f" <<<"$amber_entry"
  grep -qxF "    checksum: sha256-v2:b1d2dbc03a48dd16d3d11d078d96d9680f0e5416fdbb5d6a212f52964cd93763" <<<"$amber_entry"
fi
"$cli_path" assets build
"$cli_path" assets check
"$crystal_command" spec

"$cli_path" generate scaffold Pet name:string:required species:string:required adopted:bool
"$cli_path" generate job PublishPost --queue=default
"$cli_path" generate mailer Digest --actions=weekly
"$cli_path" generate channel Updates --topics=posts
"$cli_path" generate migration CreatePosts
# Account and Address sort ahead of application_controller.cr, so the app must
# load ApplicationController first. Comment belongs to Post through a reference.
"$cli_path" generate scaffold Account first_name:string:required
"$cli_path" generate scaffold Address street:string:required
"$cli_path" generate scaffold Post title:string:required
"$cli_path" generate scaffold Comment body:text post:reference
grep -F "field :post_id, Int64, required: true" src/schemas/comment_schema.cr
# The channel generator writes a socket; routing it proves the app compiles it.
sed -i.bak -E "s#^  routes :web do\$#  routes :web do\\
    websocket \"/updates\", UpdatesSocket#" config/routes.cr
rm -f config/routes.cr.bak
grep -F 'websocket "/updates", UpdatesSocket' config/routes.cr

grep -F "class Pet < Grant::Base" src/models/pet.cr
grep -F -- "-- +micrate Up" db/migrations/*_create_pets.sql
grep -F -- "-- +micrate Down" db/migrations/*_create_pets.sql
grep -F 'resources "/pets", PetController' config/routes.cr
grep -F 'content_type "application/x-www-form-urlencoded"' src/schemas/pet_schema.cr
grep -F 'schema :create, PetSchema' src/controllers/pet_controller.cr
grep -F 'schema :update, PetSchema' src/controllers/pet_controller.cr
grep -F 'validated_as(PetSchema)' src/controllers/pet_controller.cr
grep -F 'handle_schema_validation_failure' src/controllers/pet_controller.cr
if grep -F 'PetSchema.new(merge_request_data)' src/controllers/pet_controller.cr; then
  echo "generated scaffold bypasses Amber's automatic controller contract" >&2
  exit 1
fi
grep -F 'render(partial: "_form.ecr")' src/views/pet/new.ecr
grep -F 'hidden_field("_method", "PATCH")' src/views/pet/_form.ecr

AMBER_ENV=test "$cli_path" database migrate
AMBER_ENV=test "$cli_path" database status | grep -F "Applied At"
"$cli_path" database migrate

if find src spec -iname '*slang*' -print | grep -q .; then
  echo "a core generator emitted a Slang file" >&2
  exit 1
fi
"$crystal_command" tool format --check src spec
"$crystal_command" spec
"$cli_path" assets build
"$cli_path" assets check
"$crystal_command" build src/amber_beta_smoke.cr -o bin/amber_beta_smoke

asset_paths="$("$crystal_command" run "$script_dir/read_asset_paths.cr" -- \
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

invalid_page="$smoke_root/invalid-pet.html"
invalid_headers="$smoke_root/invalid-pet-headers.txt"
invalid_status="$(curl --silent --output "$invalid_page" --dump-header "$invalid_headers" --write-out '%{http_code}' \
  --cookie "$cookie_jar" --request POST \
  --data-urlencode "_csrf=$csrf_token" \
  --data-urlencode "name=Missing Species" \
  http://127.0.0.1:3210/pets)"
test "$invalid_status" = "422"
grep -i -F "Content-Type: text/html" "$invalid_headers"
test "$(grep -c '<!DOCTYPE html>' "$invalid_page")" -eq 1
grep -F "Please correct the following" "$invalid_page"
grep -F "species:" "$invalid_page"

curl --fail --silent --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
  http://127.0.0.1:3210/pets/new >"$new_page"
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

# Posts a form the way a browser does: GET the new page for the session cookie
# and CSRF token, then POST. Prints the status code; the body lands in $2.
post_form() {
  local resource="$1" body_file="$2" headers_file="$3"
  shift 3
  local form_page="$smoke_root/form-page.html"
  curl --fail --silent --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    "http://127.0.0.1:3210/$resource/new" >"$form_page"
  local token
  token="$(sed -n 's/.*name="_csrf" value="\([^"]*\)".*/\1/p' "$form_page" | head -1)"
  test -n "$token"
  local form_arguments=(--data-urlencode "_csrf=$token")
  local pair
  for pair in "$@"; do
    form_arguments+=(--data-urlencode "$pair")
  done
  curl --silent --output "$body_file" --dump-header "$headers_file" --write-out '%{http_code}' \
    --cookie "$cookie_jar" --request POST "${form_arguments[@]}" "http://127.0.0.1:3210/$resource"
}

created_body="$smoke_root/created.html"
test "$(post_form accounts "$created_body" "$response_headers" "first_name=Ada")" = "302"
grep -F "Location: /accounts/1" "$response_headers"
test "$(post_form addresses "$created_body" "$response_headers" "street=Main Street")" = "302"
grep -F "Location: /addresses/1" "$response_headers"
test "$(post_form posts "$created_body" "$response_headers" "title=First")" = "302"
grep -F "Location: /posts/1" "$response_headers"
test "$(post_form comments "$created_body" "$response_headers" "body=Hello" "post_id=1")" = "302"
grep -F "Location: /comments/1" "$response_headers"
curl --fail --silent http://127.0.0.1:3210/comments/1 | grep -F "Hello"

# A parent that does not exist is refused, and the form says why.
refused_body="$smoke_root/refused-comment.html"
test "$(post_form comments "$refused_body" "$response_headers" "body=Orphan" "post_id=999")" = "422"
grep -F "post must exist" "$refused_body"
test "$(post_form comments "$refused_body" "$response_headers" "body=Orphan")" = "422"
grep -F "post_id" "$refused_body"

kill "$server_pid"
wait "$server_pid" || true
server_pid=""

echo "Amber V2 beta web-app smoke test passed"
