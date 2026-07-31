#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/amber" >&2
  exit 64
fi

cli_path="$1"
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

"$cli_path" --version | grep -F "Amber CLI v2.0.2"
"$cli_path" new "$app_path" --type web --no-deps

grep -F "github: amberframework/amber" "$app_path/shard.yml"
grep -F "version: 2.0.0-beta.1" "$app_path/shard.yml"
grep -F "template: ecr" "$app_path/.amber.yml"
if grep -Eiq 'crimson-knight|grant:|gemma:|slang' "$app_path/shard.yml" "$app_path/.amber.yml"; then
  echo "generated app contains an unsupported beta dependency or template" >&2
  exit 1
fi

cd "$app_path"
shards install
crystal spec

"$cli_path" generate controller Posts index show
"$cli_path" generate schema Post title:string:required body:text
"$cli_path" generate job PublishPost --queue=default
"$cli_path" generate mailer Digest --actions=weekly
"$cli_path" generate channel Updates --topics=posts
"$cli_path" generate migration CreatePosts

if find src spec -iname '*slang*' -print | grep -q .; then
  echo "a core generator emitted a Slang file" >&2
  exit 1
fi
crystal tool format --check src spec
crystal spec
crystal build src/amber_beta_smoke.cr -o bin/amber_beta_smoke

AMBER_SERVER_PORT=3210 ./bin/amber_beta_smoke >server.log 2>&1 &
server_pid="$!"

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:3210/ >homepage.html; then
    break
  fi
  sleep 1
done

curl --fail --silent http://127.0.0.1:3210/ | grep -F "Amber V2 application is running successfully"
curl --fail --silent http://127.0.0.1:3210/css/app.css | grep -F "Application styles"

kill "$server_pid"
wait "$server_pid" || true
server_pid=""

echo "Amber V2 beta web-app smoke test passed"
