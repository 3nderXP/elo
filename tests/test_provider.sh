#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ELO="$PROJECT_DIR/elo.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-provider-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ELO_HOME="$TEST_ROOT/elo-home"
export PATH="$TEST_ROOT/bin:$PATH"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/minecraft"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "missing text: $2"; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected path: $1"; }

cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url="" output=""
while (($# > 0)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  https://cdn.test/*) printf 'fixture addon\n' >"$output" ;;
  */search) printf '%s\n' '{"hits":[{"project_id":"sodium01","slug":"sodium","project_type":"mod","title":"Sodium","downloads":42}]}' ;;
  */project/sodium) printf '%s\n' '{"id":"sodium01","slug":"sodium","title":"Sodium","project_type":"mod"}' ;;
  */project/fabric01) printf '%s\n' '{"id":"fabric01","slug":"fabric-api","title":"Fabric API","project_type":"mod"}' ;;
  */project/sodium01/version) printf '%s\n' '[{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":"fabver","project_id":"fabric01","dependency_type":"required"}]}]' ;;
  */version/sodiumver) printf '%s\n' '{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":"fabver","project_id":"fabric01","dependency_type":"required"}]}' ;;
  */version/fabver) printf '%s\n' '{"id":"fabver","project_id":"fabric01","version_number":"2.0","files":[{"url":"https://cdn.test/fabric-api.jar","filename":"fabric-api.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}' ;;
  *) printf 'unexpected URL: %s\n' "$url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"

"$ELO" init --minecraft-path "$TEST_ROOT/minecraft" >/dev/null
"$ELO" new fabric --version 1.21.1 --loader fabric >/dev/null

output="$("$ELO" search sodium --type mod --instance fabric)"
assert_contains "$output" "sodium01"
assert_contains "$output" "Sodium"

"$ELO" install fabric sodium --yes >/dev/null
assert_file "$ELO_HOME/instances/fabric/mods/sodium.jar"
assert_file "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "Sodium"
assert_contains "$output" "Fabric API"
assert_contains "$output" "managed"
assert_contains "$(cat "$ELO_HOME/instances/fabric/addons.conf")" "modrinth:fabric01_is_dependency=true"

printf 'manual\n' >"$ELO_HOME/instances/fabric/mods/manual.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "manual.jar"
assert_contains "$output" "external"
"$ELO" adopt fabric mods/manual.jar --yes >/dev/null
output="$("$ELO" addons fabric)"
assert_contains "$output" "local:"
assert_contains "$output" "managed"
if "$ELO" adopt fabric mods/manual.jar --yes >/dev/null 2>&1; then
  fail "adopt should refuse an already managed file"
fi
printf 'modified\n' >"$ELO_HOME/instances/fabric/mods/sodium.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "modified"
if "$ELO" uninstall fabric sodium --yes >/dev/null 2>&1; then
  fail "identifier uninstall should refuse a modified file"
fi
"$ELO" uninstall fabric --file mods/sodium.jar --yes >/dev/null 2>&1
assert_absent "$ELO_HOME/instances/fabric/mods/sodium.jar"
"$ELO" uninstall fabric --file mods/manual.jar --yes >/dev/null 2>&1
assert_absent "$ELO_HOME/instances/fabric/mods/manual.jar"

assert_file "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
rm "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "missing"

printf 'ok 1 - provider search, dependency install, registry, and safe uninstall\n'
printf '1..1\n'
