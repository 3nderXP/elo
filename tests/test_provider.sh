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
url="" output="" empty_search=0
while (($# > 0)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    query=no-results) empty_search=1; shift ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  https://cdn.test/*) printf 'fixture addon\n' >"$output" ;;
  */search)
    if ((empty_search == 1)); then printf '%s\n' '{"hits":[]}'
    else printf '%s\n' '{"hits":[{"project_id":"sodium01","slug":"sodium","project_type":"mod","title":"Sodium","downloads":42}]}'
    fi
    ;;
  */project/sodium) printf '%s\n' '{"id":"sodium01","slug":"sodium","title":"Sodium","project_type":"mod"}' ;;
  */project/fabric01) printf '%s\n' '{"id":"fabric01","slug":"fabric-api","title":"Fabric API","project_type":"mod"}' ;;
  */project/second) printf '%s\n' '{"id":"second01","slug":"second","title":"Second Mod","project_type":"mod"}' ;;
  */project/fabric01/version) printf '%s\n' '[{"id":"fabver","project_id":"fabric01","version_number":"2.0","files":[{"url":"https://cdn.test/fabric-api.jar","filename":"fabric-api.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}]' ;;
  */project/second01/version) printf '%s\n' '[{"id":"secondver","project_id":"second01","version_number":"1.0","files":[{"url":"https://cdn.test/second.jar","filename":"second.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}]' ;;
  */project/sodium01/version) printf '%s\n' '[{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}]' ;;
  */version/sodiumver) printf '%s\n' '{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}' ;;
  */version/fabver) printf '%s\n' '{"id":"fabver","project_id":"fabric01","version_number":"2.0","files":[{"url":"https://cdn.test/fabric-api.jar","filename":"fabric-api.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}' ;;
  */version/secondver) printf '%s\n' '{"id":"secondver","project_id":"second01","version_number":"1.0","files":[{"url":"https://cdn.test/second.jar","filename":"second.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}' ;;
  *) printf 'unexpected URL: %s\n' "$url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"

"$ELO" init --minecraft-path "$TEST_ROOT/minecraft" >/dev/null
"$ELO" new fabric --version 1.21.1 --loader fabric >/dev/null

output="$("$ELO" provider)"
assert_contains "$output" "Preferred provider: modrinth"
output="$("$ELO" provider list)"
assert_contains "$output" "modrinth"
"$ELO" provider set modrinth --yes >/dev/null
assert_contains "$(cat "$ELO_HOME/config.conf")" "PREFERRED_PROVIDER=modrinth"
if "$ELO" provider set unavailable --yes >/dev/null 2>&1; then
  fail "provider set should refuse an unavailable provider"
fi

output="$("$ELO" search sodium --type mod --instance fabric)"
assert_contains "$output" "sodium01"
assert_contains "$output" "Sodium"
output="$("$ELO" search no-results --type mod --instance fabric)"
assert_contains "$output" "info: No addons found."

printf 'fixture addon\n' >"$ELO_HOME/instances/fabric/mods/fabric-api.jar"
"$ELO" adopt fabric mods/fabric-api.jar --yes >/dev/null
output="$("$ELO" install fabric sodium --dry-run)"
assert_contains "$output" "Installation plan for sodium in fabric:"
assert_contains "$output" "Sodium"
assert_contains "$output" "Fabric API"
assert_contains "$output" "reuse verified"
assert_absent "$ELO_HOME/instances/fabric/mods/sodium.jar"
output="$("$ELO" install fabric sodium --yes 2>&1)"
assert_contains "$output" "warning: Reusing existing verified addon file: fabric-api.jar"
assert_file "$ELO_HOME/instances/fabric/mods/sodium.jar"
assert_file "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "Sodium"
assert_contains "$output" "Fabric API"
assert_contains "$output" "managed"
assert_contains "$(cat "$ELO_HOME/instances/fabric/addons.conf")" "modrinth:fabric01_is_dependency=true"
if grep -q 'local:.*fabric-api' "$ELO_HOME/instances/fabric/addons.conf"; then
  fail "verified provider install should promote adopted registry entry"
fi

printf 'manual\n' >"$ELO_HOME/instances/fabric/mods/manual.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "manual.jar"
assert_contains "$output" "external"
printf 'long\n' >"$ELO_HOME/instances/fabric/mods/addon-with-a-name-that-is-much-too-long-for-the-table.jar"
output="$("$ELO" addons fabric)"
assert_contains "$output" "..."
if printf '%s\n' "$output" | awk 'length($0) > 160 { exit 1 }'; then :; else
  fail "addon table should not exceed 160 characters"
fi
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

"$ELO" new orphan --version 1.21.1 --loader fabric >/dev/null
"$ELO" install orphan sodium --yes >/dev/null
"$ELO" install orphan second --yes >/dev/null
assert_file "$ELO_HOME/instances/orphan/mods/sodium.jar"
assert_file "$ELO_HOME/instances/orphan/mods/fabric-api.jar"
"$ELO" uninstall orphan sodium --remove-orphans --yes >/dev/null
assert_absent "$ELO_HOME/instances/orphan/mods/sodium.jar"
assert_file "$ELO_HOME/instances/orphan/mods/second.jar"
assert_file "$ELO_HOME/instances/orphan/mods/fabric-api.jar"
"$ELO" uninstall orphan second --remove-orphans --yes >/dev/null
assert_absent "$ELO_HOME/instances/orphan/mods/second.jar"
assert_absent "$ELO_HOME/instances/orphan/mods/fabric-api.jar"

printf 'ok 1 - provider search, dependency install, registry, and safe uninstall\n'
printf '1..1\n'
