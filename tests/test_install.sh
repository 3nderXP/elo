#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-install-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

INSTALL_DIR="$TEST_ROOT/install root"
BIN_DIR="$TEST_ROOT/bin"
COMMAND="$BIN_DIR/elo"
SYSTEM_PATH="$PATH"
FAKE_BIN="$TEST_ROOT/fake-bin"
FAKE_REMOTE="$TEST_ROOT/remote"
FAKE_CURL_LOG="$TEST_ROOT/curl.log"
export FAKE_REMOTE FAKE_CURL_LOG
export PATH="$BIN_DIR:$FAKE_BIN:$SYSTEM_PATH"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_release_count() {
  local expected="$1"
  local count=0 release

  for release in "$INSTALL_DIR"/releases/*; do
    [[ -d "$release" && ! -L "$release" ]] || continue
    [[ "$(basename "$release")" =~ ^[0-9]{14}-[0-9]+$ ]] || continue
    count=$((count + 1))
  done
  [[ "$count" == "$expected" ]] ||
    fail "expected $expected retained releases, found $count"
}

"$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" \
  --bin-dir "$BIN_DIR" >/dev/null

[[ -L "$INSTALL_DIR/current" ]] || fail "current should be a symlink"
[[ -L "$COMMAND" ]] || fail "the elo command should be a symlink"
[[ -x "$COMMAND" ]] || fail "the elo command should be executable"
grep -F "BIN_DIR=$BIN_DIR" "$INSTALL_DIR/install.conf" >/dev/null ||
  fail "installer should persist the command directory for updates"

output="$("$COMMAND" --help)"
[[ "$output" == *"Elo — Minecraft instance manager"* ]] ||
  fail "the installed command did not display help"

ELO_HOME="$TEST_ROOT/data" "$COMMAND" help link >/dev/null

first_release="$(readlink "$INSTALL_DIR/current")"
"$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" \
  --bin-dir "$BIN_DIR" >/dev/null
second_release="$(readlink "$INSTALL_DIR/current")"

[[ "$first_release" != "$second_release" ]] ||
  fail "reinstalling should activate a new release"
"$COMMAND" --help >/dev/null ||
  fail "the command should remain functional after reinstalling"

printf 'ok 1 - local installation creates and updates a working command\n'

mkdir -p "$FAKE_BIN" "$FAKE_REMOTE/v1.2.3" "$FAKE_REMOTE/v2.0.0-rc.1"
cp "$PROJECT_DIR/install.sh" "$FAKE_REMOTE/v1.2.3/install.sh"
cp "$PROJECT_DIR/elo.sh" "$FAKE_REMOTE/v1.2.3/elo.sh"
cp -R "$PROJECT_DIR/lib" "$FAKE_REMOTE/v1.2.3/lib"
cp "$PROJECT_DIR/install.sh" "$FAKE_REMOTE/v2.0.0-rc.1/install.sh"
cp "$PROJECT_DIR/elo.sh" "$FAKE_REMOTE/v2.0.0-rc.1/elo.sh"
cp -R "$PROJECT_DIR/lib" "$FAKE_REMOTE/v2.0.0-rc.1/lib"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
write_url=0
url=""
while (($# > 0)); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -w)
      write_url=1
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

printf '%s\n' "$url" >>"$FAKE_CURL_LOG"
if ((write_url == 1)); then
  printf 'https://github.com/3nderXP/elo/releases/tag/v1.2.3\n'
  exit 0
fi

path="${url#https://raw.githubusercontent.com/3nderXP/elo/}"
ref="${path%%/*}"
file="${path#*/}"
cp "$FAKE_REMOTE/$ref/$file" "$output"
EOF
chmod +x "$FAKE_BIN/curl"

mkdir -p "$INSTALL_DIR/releases/user-data"
stable_release="$(readlink "$INSTALL_DIR/current")"
"$COMMAND" update --yes >/dev/null 2>&1
[[ "$(readlink "$INSTALL_DIR/current")" != "$stable_release" ]] ||
  fail "stable update should activate a new release"
[[ -d "$INSTALL_DIR/releases/user-data" ]] ||
  fail "update should preserve unknown release-directory entries"
grep -F '/releases/latest' "$FAKE_CURL_LOG" >/dev/null ||
  fail "default update should resolve the latest stable release"
grep -F '/v1.2.3/install.sh' "$FAKE_CURL_LOG" >/dev/null ||
  fail "default update should install the resolved stable release"
assert_release_count 2

printf 'ok 2 - update installs the latest stable release\n'

: >"$FAKE_CURL_LOG"
"$COMMAND" update --version 2.0.0-rc.1 --yes >/dev/null 2>&1
grep -F '/v2.0.0-rc.1/install.sh' "$FAKE_CURL_LOG" >/dev/null ||
  fail "selected pre-release should be installed"
if grep -F '/releases/latest' "$FAKE_CURL_LOG" >/dev/null; then
  fail "selected version should not resolve the latest stable release"
fi
assert_release_count 2

printf 'ok 3 - update accepts a pre-release and retains two releases\n'
printf '1..3\n'
