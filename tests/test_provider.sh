#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ELO="$PROJECT_DIR/elo.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-provider-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ELO_HOME="$TEST_ROOT/elo-home"
export PATH="$TEST_ROOT/bin:$PATH"
export ELO_TEST_SEARCH_LOG="$TEST_ROOT/search.log"
export ELO_TEST_CURL_ARGS_LOG="$TEST_ROOT/curl-args.log"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/minecraft"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "missing text: $2"; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected path: $1"; }

cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url="" output="" empty_search=0 offset="" limit=""
printf '%s\n' "$*" >>"$ELO_TEST_CURL_ARGS_LOG"
while (($# > 0)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    query=no-results) empty_search=1; shift ;;
    offset=*) offset="$1"; shift ;;
    limit=*) limit="$1"; shift ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  https://cdn.test/*) printf 'fixture addon\n' >"$output" ;;
  */search)
    printf '%s %s\n' "$limit" "$offset" >>"$ELO_TEST_SEARCH_LOG"
    if ((empty_search == 1)); then printf '%s\n' '{"hits":[],"total_hits":0}'
    else printf '%s\n' '{"hits":[{"project_id":"sodium01","slug":"sodium","project_type":"mod","title":"Sodium","downloads":42}],"total_hits":201}'
    fi
    ;;
  */project/sodium) printf '%s\n' '{"id":"sodium01","slug":"sodium","title":"Sodium","project_type":"mod"}' ;;
  */project/fabric01) printf '%s\n' '{"id":"fabric01","slug":"fabric-api","title":"Fabric API","project_type":"mod"}' ;;
  */project/second) printf '%s\n' '{"id":"second01","slug":"second","title":"Second Mod","project_type":"mod"}' ;;
  */project/psx-core) printf '%s\n' '{"id":"shader01","slug":"psx-core","title":"PSX-Core Shader","project_type":"shader"}' ;;
  */project/fabric01/version) printf '%s\n' '[{"id":"fabver","project_id":"fabric01","version_number":"2.0","files":[{"url":"https://cdn.test/fabric-api.jar","filename":"fabric-api.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}]' ;;
  */project/second01/version) printf '%s\n' '[{"id":"secondver","project_id":"second01","version_number":"1.0","files":[{"url":"https://cdn.test/second.jar","filename":"second.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}]' ;;
  */project/shader01/version) printf '%s\n' '[{"id":"shaderver","project_id":"shader01","version_number":"0.1.6","loaders":["iris","optifine"],"files":[{"url":"https://cdn.test/psx-core.zip","filename":"psx-core.zip","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}]' ;;
  */project/sodium01/version) printf '%s\n' '[{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}]' ;;
  */version/sodiumver) printf '%s\n' '{"id":"sodiumver","project_id":"sodium01","version_number":"1.0","files":[{"url":"https://cdn.test/sodium.jar","filename":"sodium.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}' ;;
  */version/fabver) printf '%s\n' '{"id":"fabver","project_id":"fabric01","version_number":"2.0","files":[{"url":"https://cdn.test/fabric-api.jar","filename":"fabric-api.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}' ;;
  */version/secondver) printf '%s\n' '{"id":"secondver","project_id":"second01","version_number":"1.0","files":[{"url":"https://cdn.test/second.jar","filename":"second.jar","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[{"version_id":null,"project_id":"fabric01","dependency_type":"required"}]}' ;;
  */version/shaderver) printf '%s\n' '{"id":"shaderver","project_id":"shader01","version_number":"0.1.6","loaders":["iris","optifine"],"files":[{"url":"https://cdn.test/psx-core.zip","filename":"psx-core.zip","primary":true,"hashes":{"sha512":"3bad9020d8b4bc8fb6c719e6ed53a1a834276e20848fba7219d6b185bd03c2a6b6fe0d18696ebc230f36f14b02d2d065d79dcae0a36a5c12341b52106d336c11"}}],"dependencies":[]}' ;;
  *) printf 'unexpected URL: %s\n' "$url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"

"$ELO" init --minecraft-path "$TEST_ROOT/minecraft" >/dev/null
"$ELO" instances create fabric --version 1.21.1 --loader fabric >/dev/null

output="$("$ELO" addons provider)"
assert_contains "$output" "Preferred provider: modrinth"
output="$("$ELO" addons provider list)"
assert_contains "$output" "modrinth"
"$ELO" addons provider set modrinth --yes >/dev/null
assert_contains "$(cat "$ELO_HOME/config.conf")" "PREFERRED_PROVIDER=modrinth"
if "$ELO" addons provider set unavailable --yes >/dev/null 2>&1; then
  fail "provider set should refuse an unavailable provider"
fi

output="$("$ELO" addons search sodium --type mod --instance fabric)"
assert_contains "$output" "sodium01"
assert_contains "$output" "Sodium"
assert_contains "$(cat "$ELO_TEST_SEARCH_LOG")" "limit=10 offset=0"
output="$("$ELO" addons search no-results --type mod --instance fabric)"
assert_contains "$output" "info: No addons found."
"$ELO" addons search fixture-pack --type modpack --instance fabric >/dev/null
assert_contains "$(cat "$ELO_TEST_CURL_ARGS_LOG")" "project_type:modpack"

: >"$ELO_TEST_CURL_ARGS_LOG"
"$ELO" addons search psx-core --type shader --instance fabric >/dev/null
assert_contains "$(cat "$ELO_TEST_CURL_ARGS_LOG")" "project_type:shader"
if grep -F 'categories:fabric' "$ELO_TEST_CURL_ARGS_LOG" >/dev/null; then
  fail "shader search should not inherit the instance mod loader"
fi
output="$("$ELO" addons install fabric psx-core --platform iris --dry-run)"
assert_contains "$output" "PSX-Core Shader"
assert_contains "$(cat "$ELO_TEST_CURL_ARGS_LOG")" 'loaders=["iris"]'
if "$ELO" addons install fabric psx-core --dry-run >/dev/null 2>&1; then
  fail "shader installation should require an explicit platform"
fi
if "$ELO" addons install fabric psx-core --platform forge --dry-run >/dev/null 2>&1; then
  fail "shader platform should accept only iris or optifine"
fi

printf 'fixture addon\n' >"$ELO_HOME/instances/fabric/mods/fabric-api.jar"
"$ELO" addons adopt fabric mods/fabric-api.jar --yes >/dev/null
output="$("$ELO" addons install fabric sodium --dry-run)"
assert_contains "$output" "Installation plan for sodium in fabric:"
assert_contains "$output" "Sodium"
assert_contains "$output" "Fabric API"
assert_contains "$output" "reuse verified"
assert_absent "$ELO_HOME/instances/fabric/mods/sodium.jar"
output="$("$ELO" addons install fabric sodium --yes 2>&1)"
assert_contains "$output" "warning: Reusing existing verified addon file: fabric-api.jar"
assert_file "$ELO_HOME/instances/fabric/mods/sodium.jar"
assert_file "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
output="$("$ELO" addons list fabric)"
assert_contains "$output" "Sodium"
assert_contains "$output" "Fabric API"
assert_contains "$output" "managed"
assert_contains "$(cat "$ELO_HOME/instances/fabric/addons.conf")" "modrinth:fabric01_is_dependency=true"
if grep -q 'local:.*fabric-api' "$ELO_HOME/instances/fabric/addons.conf"; then
  fail "verified provider install should promote adopted registry entry"
fi

printf 'manual\n' >"$ELO_HOME/instances/fabric/mods/manual.jar"
output="$("$ELO" addons list fabric)"
assert_contains "$output" "manual.jar"
assert_contains "$output" "external"
printf 'long\n' >"$ELO_HOME/instances/fabric/mods/addon-with-a-name-that-is-much-too-long-for-the-table.jar"
output="$("$ELO" addons list fabric)"
assert_contains "$output" "..."
if printf '%s\n' "$output" | awk 'length($0) > 160 { exit 1 }'; then :; else
  fail "addon table should not exceed 160 characters"
fi
"$ELO" addons adopt fabric mods/manual.jar --yes >/dev/null
output="$("$ELO" addons list fabric)"
assert_contains "$output" "local:"
assert_contains "$output" "managed"
if "$ELO" addons adopt fabric mods/manual.jar --yes >/dev/null 2>&1; then
  fail "adopt should refuse an already managed file"
fi
printf 'modified\n' >"$ELO_HOME/instances/fabric/mods/sodium.jar"
output="$("$ELO" addons list fabric)"
assert_contains "$output" "modified"
if "$ELO" addons remove fabric sodium --yes >/dev/null 2>&1; then
  fail "identifier uninstall should refuse a modified file"
fi
"$ELO" addons remove fabric --file mods/sodium.jar --yes >/dev/null 2>&1
assert_absent "$ELO_HOME/instances/fabric/mods/sodium.jar"
"$ELO" addons remove fabric --file mods/manual.jar --yes >/dev/null 2>&1
assert_absent "$ELO_HOME/instances/fabric/mods/manual.jar"

assert_file "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
rm "$ELO_HOME/instances/fabric/mods/fabric-api.jar"
output="$("$ELO" addons list fabric)"
assert_contains "$output" "missing"

"$ELO" instances create orphan --version 1.21.1 --loader fabric >/dev/null
"$ELO" addons install orphan sodium --yes >/dev/null
"$ELO" addons install orphan second --yes >/dev/null
assert_file "$ELO_HOME/instances/orphan/mods/sodium.jar"
assert_file "$ELO_HOME/instances/orphan/mods/fabric-api.jar"
"$ELO" addons remove orphan sodium --remove-orphans --yes >/dev/null
assert_absent "$ELO_HOME/instances/orphan/mods/sodium.jar"
assert_file "$ELO_HOME/instances/orphan/mods/second.jar"
assert_file "$ELO_HOME/instances/orphan/mods/fabric-api.jar"
"$ELO" addons remove orphan second --remove-orphans --yes >/dev/null
assert_absent "$ELO_HOME/instances/orphan/mods/second.jar"
assert_absent "$ELO_HOME/instances/orphan/mods/fabric-api.jar"

"$ELO" instances create cache-test --version 1.21.1 --loader fabric >/dev/null
"$ELO" addons install cache-test sodium --yes >/dev/null

# shellcheck source=../lib/utils.sh
source "$PROJECT_DIR/lib/utils.sh"
# shellcheck source=../lib/config.sh
source "$PROJECT_DIR/lib/config.sh"
# shellcheck source=../lib/instance.sh
source "$PROJECT_DIR/lib/instance.sh"
# shellcheck source=../lib/provider_modrinth.sh
source "$PROJECT_DIR/lib/provider_modrinth.sh"
# shellcheck source=../lib/provider.sh
source "$PROJECT_DIR/lib/provider.sh"

ELO_HASH_LOG="$TEST_ROOT/hash.log"
elo_file_sha512() {
  printf 'hash\n' >>"$ELO_HASH_LOG"
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$1" | awk '{print $1}'
  else
    shasum -a 512 "$1" | awk '{print $1}'
  fi
}

inventory_file="$TEST_ROOT/cache-inventory"
elo_addons_list_inventory cache-test >"$inventory_file"
: >"$ELO_HASH_LOG"
elo_addons_list_inventory_page cache-test "$inventory_file" 0 100 >/dev/null
[[ -s "$ELO_HASH_LOG" ]] || fail "first cached listing should hash managed files"

: >"$ELO_HASH_LOG"
elo_addons_list_inventory_page cache-test "$inventory_file" 0 100 >/dev/null
[[ ! -s "$ELO_HASH_LOG" ]] || fail "unchanged cached listing should not repeat hashes"

printf 'changed addon content\n' >"$ELO_HOME/instances/cache-test/mods/sodium.jar"
: >"$ELO_HASH_LOG"
output="$(elo_addons_list_inventory_page cache-test "$inventory_file" 0 100)"
[[ "$(wc -l <"$ELO_HASH_LOG")" == "1" ]] || fail "only the changed addon should be rehashed"
assert_contains "$output" "modified"

inventory_count="$(wc -l <"$inventory_file")"
elo_addons_list_inventory_page cache-test "$inventory_file" "$((inventory_count - 1))" 10 >/dev/null ||
  fail "a partial final addon page should return success"

assert_file "$ELO_ADDON_CACHE_DIR/cache-test/$(basename "$(elo_addon_cache_file cache-test modrinth:sodium01)")"
"$ELO" instances remove cache-test --yes >/dev/null
assert_absent "$ELO_ADDON_CACHE_DIR/cache-test"

printf 'ok 1 - provider search, dependency install, registry, and safe removal\n'
printf '1..1\n'
