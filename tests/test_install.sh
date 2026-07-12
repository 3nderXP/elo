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

mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/gum" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN/gum"

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

mkdir -p "$FAKE_REMOTE/v1.2.3" "$FAKE_REMOTE/v2.0.0-rc.1"
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

GUM_ROOT="$TEST_ROOT/gum-install"
GUM_BIN="$GUM_ROOT/bin"
GUM_FAKE_BIN="$GUM_ROOT/fake-bin"
GUM_REMOTE="$GUM_ROOT/remote"
GUM_INSTALL_DIR="$GUM_ROOT/elo"
mkdir -p "$GUM_BIN" "$GUM_FAKE_BIN" "$GUM_REMOTE"
gum_os="$(uname -s)"
case "$(uname -m)" in
  x86_64 | amd64) gum_arch="x86_64" ;;
  arm64 | aarch64) gum_arch="arm64" ;;
  armv7l | armv7) gum_arch="armv7" ;;
  *) fail "unsupported test architecture" ;;
esac
GUM_ASSET="gum_0.17.0_${gum_os}_${gum_arch}.tar.gz"
GUM_ARCHIVE_DIR="${GUM_ASSET%.tar.gz}"
mkdir -p "$GUM_REMOTE/archive/$GUM_ARCHIVE_DIR"
cat >"$GUM_REMOTE/archive/$GUM_ARCHIVE_DIR/gum" <<'EOF'
#!/usr/bin/env bash
printf 'gum test fixture\n'
EOF
chmod +x "$GUM_REMOTE/archive/$GUM_ARCHIVE_DIR/gum"
tar -czf "$GUM_REMOTE/$GUM_ASSET" -C "$GUM_REMOTE/archive" "$GUM_ARCHIVE_DIR"
if command -v sha256sum >/dev/null 2>&1; then
  gum_hash="$(sha256sum "$GUM_REMOTE/$GUM_ASSET")"
else
  gum_hash="$(shasum -a 256 "$GUM_REMOTE/$GUM_ASSET")"
fi
printf '%s  %s\n' "${gum_hash%% *}" "$GUM_ASSET" >"$GUM_REMOTE/checksums.txt"
export GUM_REMOTE
cat >"$GUM_FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($# > 0)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
cp "$GUM_REMOTE/${url##*/}" "$output"
EOF
chmod +x "$GUM_FAKE_BIN/curl"

PATH="$GUM_FAKE_BIN:$SYSTEM_PATH" ELO_GUM_FORCE_INSTALL=1 \
  "$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$GUM_INSTALL_DIR" --bin-dir "$GUM_BIN" >/dev/null
[[ -L "$GUM_BIN/gum" && -x "$GUM_BIN/gum" ]] ||
  fail "installer should create a working Gum command"
[[ "$("$GUM_BIN/gum")" == "gum test fixture" ]] ||
  fail "installed Gum command should execute the verified artifact"

printf 'ok 4 - installer downloads and verifies Gum in user space\n'
printf '1..4\n'
