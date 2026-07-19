#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ELO="$PROJECT_DIR/elo.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-mrpack-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ELO_HOME="$TEST_ROOT/elo-home"
export PATH="$TEST_ROOT/bin:$PATH"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/minecraft" "$TEST_ROOT/downloads"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "missing text: $2"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "unexpected text: $2"; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected path: $1"; }

printf 'fixture addon\n' >"$TEST_ROOT/downloads/example.jar"
printf 'optional pack\n' >"$TEST_ROOT/downloads/optional.zip"
printf 'server only\n' >"$TEST_ROOT/downloads/server.jar"

cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url="" output=""
while (($# > 0)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */project/fixture-pack)
    printf '%s\n' '{"id":"pack01","slug":"fixture-pack","title":"Fixture Pack","project_type":"modpack"}'
    ;;
  */project/pack01/version)
    jq -cn --arg hash "$ELO_MRPACK_ARCHIVE_HASH" '[{
      id:"packver",project_id:"pack01",version_number:"1.0.0",loaders:["fabric"],
      files:[{url:"https://cdn.modrinth.com/data/pack01/versions/packver/fixture.mrpack",
        filename:"fixture.mrpack",primary:true,hashes:{sha512:$hash}}],dependencies:[]}]'
    ;;
  */version/packver)
    jq -cn --arg hash "$ELO_MRPACK_ARCHIVE_HASH" '{
      id:"packver",project_id:"pack01",version_number:"1.0.0",loaders:["fabric"],
      files:[{url:"https://cdn.modrinth.com/data/pack01/versions/packver/fixture.mrpack",
        filename:"fixture.mrpack",primary:true,hashes:{sha512:$hash}}],dependencies:[]}'
    ;;
  */fixture.mrpack) cp "$ELO_MRPACK_ARCHIVE" "$output" ;;
  */example.jar) cp "$ELO_MRPACK_FIXTURES/example.jar" "$output" ;;
  */optional.zip) cp "$ELO_MRPACK_FIXTURES/optional.zip" "$output" ;;
  */server.jar) cp "$ELO_MRPACK_FIXTURES/server.jar" "$output" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
export ELO_MRPACK_FIXTURES="$TEST_ROOT/downloads"

file_sha512() {
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$1" | awk '{print $1}'
  else
    shasum -a 512 "$1" | awk '{print $1}'
  fi
}

create_pack() {
  local directory="$1" output="$2" unsafe_path="${3:-}"
  local example_hash optional_hash server_hash example_size optional_size server_size path
  example_hash="$(file_sha512 "$TEST_ROOT/downloads/example.jar")"
  optional_hash="$(file_sha512 "$TEST_ROOT/downloads/optional.zip")"
  server_hash="$(file_sha512 "$TEST_ROOT/downloads/server.jar")"
  example_size="$(wc -c <"$TEST_ROOT/downloads/example.jar" | tr -d ' ')"
  optional_size="$(wc -c <"$TEST_ROOT/downloads/optional.zip" | tr -d ' ')"
  server_size="$(wc -c <"$TEST_ROOT/downloads/server.jar" | tr -d ' ')"
  path="${unsafe_path:-mods/example.jar}"
  mkdir -p "$directory/overrides/config" "$directory/client-overrides/config" \
    "$directory/server-overrides/config"
  printf 'base config\n' >"$directory/overrides/config/example.txt"
  printf 'client config\n' >"$directory/client-overrides/config/example.txt"
  printf 'ignored root\n' >"$directory/overrides/options.txt"
  printf 'server config\n' >"$directory/server-overrides/config/server.txt"
  jq -n --arg path "$path" --arg example_hash "$example_hash" \
    --arg optional_hash "$optional_hash" --arg server_hash "$server_hash" \
    --argjson example_size "$example_size" --argjson optional_size "$optional_size" \
    --argjson server_size "$server_size" '{
      formatVersion: 1, game: "minecraft", versionId: "pack-1.0",
      name: "Fixture Pack",
      dependencies: {minecraft: "1.21.1", "fabric-loader": "0.16.0"},
      files: [
        {path:$path, hashes:{sha512:$example_hash}, fileSize:$example_size,
          downloads:["https://github.com/example/missing.jar",
            "https://cdn.modrinth.com/data/project01/versions/version01/example.jar"],
          env:{client:"required",server:"required"}},
        {path:"resourcepacks/optional.zip", hashes:{sha512:$optional_hash}, fileSize:$optional_size,
          downloads:["https://cdn.modrinth.com/data/project02/versions/version02/optional.zip"],
          env:{client:"optional",server:"unsupported"}},
        {path:"resourcepacks/optional-copy.zip", hashes:{sha512:$optional_hash}, fileSize:$optional_size,
          downloads:["https://cdn.modrinth.com/data/project02/versions/version02/optional.zip"],
          env:{client:"optional",server:"unsupported"}},
        {path:"mods/server.jar", hashes:{sha512:$server_hash}, fileSize:$server_size,
          downloads:["https://cdn.modrinth.com/data/project03/versions/version03/server.jar"],
          env:{client:"unsupported",server:"required"}}
      ]
    }' >"$directory/modrinth.index.json"
  (cd "$directory" && zip -qr "$output" .)
}

"$ELO" init --minecraft-path "$TEST_ROOT/minecraft" >/dev/null
PACK_DIR="$TEST_ROOT/pack"
PACK="$TEST_ROOT/Fixture Pack.mrpack"
create_pack "$PACK_DIR" "$PACK"
export ELO_MRPACK_ARCHIVE="$PACK"
export ELO_MRPACK_ARCHIVE_HASH="$(file_sha512 "$PACK")"

"$ELO" instances create api-empty --version unknown --loader unknown >/dev/null
output="$("$ELO" addons install api-empty fixture-pack --yes 2>&1)"
assert_not_contains "$output" "is not empty"
assert_contains "$output" "Modpack installed into instance: api-empty"
assert_file "$ELO_HOME/instances/api-empty/mods/example.jar"
api_config="$(cat "$ELO_HOME/instances/api-empty/instance.conf")"
assert_contains "$api_config" "MINECRAFT_VERSION=1.21.1"
assert_contains "$api_config" "LOADER=fabric"
assert_contains "$api_config" "MODPACK_SOURCE=modrinth:pack01"
assert_contains "$api_config" "MODPACK_SOURCE_VERSION=packver"

"$ELO" instances create bad-api --version unknown --loader unknown >/dev/null
valid_archive_hash="$ELO_MRPACK_ARCHIVE_HASH"
export ELO_MRPACK_ARCHIVE_HASH="$(printf '%0128d' 0)"
if "$ELO" addons install bad-api fixture-pack --yes >/dev/null 2>&1; then
  fail "provider install should refuse a modpack archive SHA-512 mismatch"
fi
assert_absent "$ELO_HOME/instances/bad-api/mods/example.jar"
export ELO_MRPACK_ARCHIVE_HASH="$valid_archive_hash"

"$ELO" instances create local-empty --version unknown --loader unknown >/dev/null
output="$("$ELO" addons install local-empty "$PACK" --yes 2>&1)"
assert_not_contains "$output" "is not empty"
assert_contains "$output" "Modpack installed into instance: local-empty"
assert_file "$ELO_HOME/instances/local-empty/resourcepacks/optional.zip"

"$ELO" instances create populated --version 1.21.1 --loader fabric >/dev/null
printf 'existing addon\n' >"$ELO_HOME/instances/populated/mods/existing.jar"
output="$("$ELO" addons install populated fixture-pack --dry-run 2>&1)"
assert_contains "$output" "Instance 'populated' is not empty"
assert_contains "$output" "using an empty instance is recommended"
assert_absent "$ELO_HOME/instances/populated/mods/example.jar"

output="$("$ELO" instances import fixture "$PACK" --yes 2>&1)"
assert_contains "$output" "Fixture Pack (pack-1.0)"
assert_contains "$output" "Optional client files included: 2"
assert_contains "$output" "Ignored 1 overrides file(s) outside Elo-managed folders: options.txt"
assert_contains "$output" "Ignored server-overrides for client instance import."
assert_contains "$output" "Modpack progress: 1/3 (33%): mods/example.jar"
assert_file "$ELO_HOME/instances/fixture/mods/example.jar"
assert_file "$ELO_HOME/instances/fixture/resourcepacks/optional.zip"
assert_absent "$ELO_HOME/instances/fixture/mods/server.jar"
assert_absent "$ELO_HOME/instances/fixture/options.txt"
[[ "$(cat "$ELO_HOME/instances/fixture/config/example.txt")" == "client config" ]] || \
  fail "client-overrides should replace base overrides"
instance_config="$(cat "$ELO_HOME/instances/fixture/instance.conf")"
assert_contains "$instance_config" "MINECRAFT_VERSION=1.21.1"
assert_contains "$instance_config" "LOADER=fabric"
assert_contains "$instance_config" "MODPACK_NAME=Fixture Pack"
registry="$(cat "$ELO_HOME/instances/fixture/addons.conf")"
assert_contains "$registry" "modrinth:project01"
assert_contains "$registry" "modrinth:project02"
assert_contains "$registry" "local:"

if "$ELO" instances import fixture "$PACK" --yes >/dev/null 2>&1; then
  fail "import should refuse an existing instance"
fi

UNSAFE_DIR="$TEST_ROOT/unsafe-pack"
UNSAFE_PACK="$TEST_ROOT/unsafe.mrpack"
create_pack "$UNSAFE_DIR" "$UNSAFE_PACK" "../escape.jar"
if "$ELO" instances import unsafe "$UNSAFE_PACK" --yes >/dev/null 2>&1; then
  fail "import should refuse traversal in index paths"
fi
assert_absent "$ELO_HOME/instances/unsafe"
assert_absent "$TEST_ROOT/escape.jar"

BAD_DIR="$TEST_ROOT/bad-pack"
BAD_PACK="$TEST_ROOT/bad-hash.mrpack"
create_pack "$BAD_DIR" "$BAD_PACK"
jq '.files[0].hashes.sha512 = ("0" * 128)' "$BAD_DIR/modrinth.index.json" >"$BAD_DIR/index.tmp"
mv "$BAD_DIR/index.tmp" "$BAD_DIR/modrinth.index.json"
rm -f -- "$BAD_PACK"
(cd "$BAD_DIR" && zip -qr "$BAD_PACK" .)
if "$ELO" instances import bad-hash "$BAD_PACK" --yes >/dev/null 2>&1; then
  fail "import should refuse a SHA-512 mismatch"
fi
assert_absent "$ELO_HOME/instances/bad-hash"
if find "$ELO_HOME/instances" -maxdepth 1 -name '.elo-mrpack-*' | grep . >/dev/null; then
  fail "failed import should remove its staging directory"
fi

printf 'ok 1 - safe atomic Modrinth modpack import\n'
printf '1..1\n'
