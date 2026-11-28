#!/usr/bin/env bash
# Checks that the app `amber new` generates links no regex engine and no C SQLite library.
#
# 1. scripts/linkage/regex_control.cr links PCRE2, which proves the check can fail.
# 2. `amber new linkage_probe -d sqlite` builds into a binary that links no
#    libpcre2 and holds no pcre2_ symbol, and its home page answers 200.
#    It runs on Grant's own SQLite engine, so it also links no libsqlite3 and
#    holds no sqlite3_ symbol.
# 3. After `amber generate scaffold` adds a Grant model, controller and schema,
#    the rebuilt binary still links neither, `amber database migrate` applies
#    the migration, and the app's specs pass.
#
# usage: scripts/check_generated_app_linkage.sh /path/to/amber [OUTPUT_DIR]
# Set CRYSTAL to choose the compiler; crystal-alpha is preferred when present.
# Minecart must be on PATH (scripts/install_pinned_minecart.sh puts it there).
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
output_directory="${2:-${TMPDIR:-/tmp}/amber-generated-app-linkage}"
probe_port="${LINKAGE_PROBE_PORT:-39128}"
if [[ -z "${CRYSTAL:-}" ]]; then
  if command -v crystal-alpha >/dev/null 2>&1; then CRYSTAL=crystal-alpha; else CRYSTAL=crystal; fi
fi
command -v minecart >/dev/null 2>&1 || { echo "Minecart is required to generate the app" >&2; exit 1; }

rm -rf "$output_directory"
mkdir -p "$output_directory"
# The script changes into the app, so keep the output directory absolute.
output_directory="$(cd "$output_directory" && pwd)"
app_path="$output_directory/linkage_probe"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

list_libraries() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    otool -L "$1" | tail -n +2 | awk '{print $1}'
  else
    ldd "$1" | awk '{print $1}'
  fi
}

count_pcre2_libraries() {
  list_libraries "$1" | grep -c pcre2 || true
}

count_pcre2_symbols() {
  nm "$1" 2>/dev/null | grep -c pcre2_ || true
}

count_sqlite_libraries() {
  list_libraries "$1" | grep -c libsqlite3 || true
}

# Plain nm, as for PCRE2: a statically linked libsqlite3 defines its symbols.
count_sqlite_symbols() {
  nm "$1" 2>/dev/null | grep -c ' _\{0,1\}sqlite3_' || true
}

status=0

# Fails the run when the binary reaches the C SQLite library.
check_binary_is_sqlite_library_free() {
  local label="$1" binary="$2"
  local library_count symbol_count
  library_count="$(count_sqlite_libraries "$binary")"
  symbol_count="$(count_sqlite_symbols "$binary")"
  if [[ "$library_count" -ne 0 || "$symbol_count" -ne 0 ]]; then
    echo "FAIL: $label reaches the C SQLite library ($library_count libraries, $symbol_count sqlite3_ symbols)"
    status=1
  else
    echo "ok: $label links no libsqlite3 and holds no sqlite3_ symbol"
  fi
}

# Fails the run when the binary reaches PCRE2, and prints what it links.
check_binary_is_pcre2_free() {
  local label="$1" binary="$2"
  echo "$label links:"
  list_libraries "$binary" | sed 's/^/  /'
  local library_count symbol_count
  library_count="$(count_pcre2_libraries "$binary")"
  symbol_count="$(count_pcre2_symbols "$binary")"
  if [[ "$library_count" -ne 0 || "$symbol_count" -ne 0 ]]; then
    echo "FAIL: $label reaches PCRE2 ($library_count libraries, $symbol_count pcre2_ symbols)"
    status=1
  else
    echo "ok: $label links no PCRE2 and holds no pcre2_ symbol"
  fi
}

"$CRYSTAL" --version | head -1

"$CRYSTAL" build "$script_dir/linkage/regex_control.cr" -o "$output_directory/regex_control"
control_library_count="$(count_pcre2_libraries "$output_directory/regex_control")"
control_symbol_count="$(count_pcre2_symbols "$output_directory/regex_control")"
if [[ "$control_library_count" -eq 0 && "$control_symbol_count" -eq 0 ]]; then
  echo "FAIL: regex_control shows no PCRE2, so this check cannot see it"
  status=1
else
  echo "ok: regex_control reaches PCRE2 ($control_library_count libraries, $control_symbol_count pcre2_ symbols), so the check can fail"
fi

(cd "$output_directory" && "$cli_path" new linkage_probe -d sqlite -y --skip-agent-setup)
cd "$app_path"

mkdir -p bin
"$CRYSTAL" build src/linkage_probe.cr -o bin/linkage_probe
check_binary_is_pcre2_free "default app" bin/linkage_probe
check_binary_is_sqlite_library_free "default app" bin/linkage_probe

AMBER_ENV=development AMBER_SERVER_PORT="$probe_port" bin/linkage_probe > "$output_directory/server.log" 2>&1 &
server_pid=$!
home_status="000"
for _ in $(seq 1 50); do
  home_status="$(curl --silent --output /dev/null --max-time 1 --write-out '%{http_code}' "http://127.0.0.1:$probe_port/" || true)"
  [[ "$home_status" == "200" ]] && break
  sleep 0.2
done
if [[ "$home_status" == "200" ]]; then
  echo "ok: the default app answers GET / with 200"
else
  echo "FAIL: the default app answered GET / with $home_status"
  tail -20 "$output_directory/server.log"
  status=1
fi
cleanup
server_pid=""

"$cli_path" generate scaffold Pet name:string:required species:string:required adopted:bool
"$CRYSTAL" build src/linkage_probe.cr -o bin/linkage_probe_scaffold
check_binary_is_pcre2_free "scaffolded app" bin/linkage_probe_scaffold
check_binary_is_sqlite_library_free "scaffolded app" bin/linkage_probe_scaffold
AMBER_ENV=test "$cli_path" database migrate
# Grant's engine wrote the database file; the C sqlite3 tool must read it as sound.
sqlite_tool="$(command -v sqlite3 || true)"
if [[ -n "$sqlite_tool" ]]; then
  # -readonly keeps the tool from creating an empty database when the file is missing.
  if [[ ! -s db/linkage_probe_test.db ]]; then
    integrity="no database file at db/linkage_probe_test.db"
  elif ! integrity="$("$sqlite_tool" -readonly db/linkage_probe_test.db "PRAGMA integrity_check" 2>&1)"; then
    integrity="sqlite3 failed: $integrity"
  fi
  if [[ "$integrity" == "ok" ]]; then
    echo "ok: $sqlite_tool reports integrity_check ok for the migrated test database"
  else
    echo "FAIL: $sqlite_tool reports integrity_check: $integrity"
    status=1
  fi
else
  echo "FAIL: no sqlite3 tool to check the migrated database"
  status=1
fi
AMBER_ENV=test "$CRYSTAL" spec

exit $status
