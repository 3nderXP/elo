#!/usr/bin/env bash

set -euo pipefail

unset ELO_APPLICATIONS_DIR ELO_TERMINAL ELO_GUM_FORCE_INSTALL
unset ELO_GUM_REPOSITORY ELO_GUM_VERSION ELO_REPOSITORY ELO_REF

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-install-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
export XDG_DATA_HOME="$TEST_ROOT/xdg data"
export ELO_APPLICATIONS_DIR="$XDG_DATA_HOME/applications"

INSTALL_DIR="$TEST_ROOT/install root"
BIN_DIR="$TEST_ROOT/bin"
COMMAND="$BIN_DIR/elo"
SYSTEM_PATH="$PATH"
FAKE_BIN="$TEST_ROOT/fake-bin"
FAKE_REMOTE="$TEST_ROOT/remote"
FAKE_CURL_LOG="$TEST_ROOT/curl.log"
export FAKE_REMOTE FAKE_CURL_LOG
export PATH="$BIN_DIR:$FAKE_BIN:$SYSTEM_PATH"
TERMINAL_LOG="$TEST_ROOT/terminal.log"
OPEN_LOG="$TEST_ROOT/open.log"
export TERMINAL_LOG
export OPEN_LOG
export TERM_PROGRAM=kitty

mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/gum" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "choose" ]]; then
  for option in "$@"; do
    if [[ "$option" == "Kitty" ]]; then
      printf 'Kitty\n'
      exit 0
    fi
  done
fi
exit 0
EOF
chmod +x "$FAKE_BIN/gum"
cat >"$FAKE_BIN/kitty" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TERMINAL_LOG"
EOF
chmod +x "$FAKE_BIN/kitty"
cat >"$FAKE_BIN/warp-terminal" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$OPEN_LOG"
EOF
cat >"$FAKE_BIN/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$OPEN_LOG"
EOF
chmod +x "$FAKE_BIN/warp-terminal" "$FAKE_BIN/xdg-open"
cat >"$FAKE_BIN/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$OPEN_LOG"
EOF
chmod +x "$FAKE_BIN/open"

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
[[ -f "$INSTALL_DIR/current/assets/branding/elo.asc" ]] ||
  fail "the installed release should include the terminal logo"
[[ -f "$INSTALL_DIR/current/assets/branding/shortcut-icon.png" ]] ||
  fail "the installed release should include the shortcut icon"
cmp "$PROJECT_DIR/assets/branding/elo.asc" \
  "$INSTALL_DIR/current/assets/branding/elo.asc" >/dev/null ||
  fail "the installer should preserve the terminal logo byte for byte"
grep -F "BIN_DIR=$BIN_DIR" "$INSTALL_DIR/install.conf" >/dev/null ||
  fail "installer should persist the command directory for updates"
SHORTCUT="$ELO_APPLICATIONS_DIR/elo.desktop"
if [[ ! -f "$SHORTCUT" ]]; then
  printf 'diagnostic: expected shortcut: %s\n' "$SHORTCUT" >&2
  printf 'diagnostic: install.conf follows\n' >&2
  sed -n '1,20p' "$INSTALL_DIR/install.conf" >&2 || true
  fail "installer should create an application shortcut"
fi
grep -Fx 'X-Elo-Managed=true' "$SHORTCUT" >/dev/null ||
  fail "shortcut should be marked as installer-managed"
grep -F "TERMINAL_COMMAND=$FAKE_BIN/kitty" "$INSTALL_DIR/install.conf" >/dev/null ||
  fail "installer should persist the detected terminal"
"$INSTALL_DIR/current/lib/launcher.sh"
grep -Fx "$INSTALL_DIR/current/elo.sh" "$TERMINAL_LOG" >/dev/null ||
  fail "shortcut launcher should open Elo in the selected terminal"

awk -F= '$1 !~ /^(SHORTCUT_ENABLED|SHORTCUT_PATH|TERMINAL_ID|TERMINAL_COMMAND|TERMINAL_MODE|WARP_CONFIG_PATH)$/ { print }' \
  "$INSTALL_DIR/install.conf" >"$INSTALL_DIR/install.conf.legacy"
mv "$INSTALL_DIR/install.conf.legacy" "$INSTALL_DIR/install.conf"
rm "$SHORTCUT"
"$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" >/dev/null
[[ -f "$SHORTCUT" ]] || fail "legacy installations should receive shortcut setup"
grep -F 'SHORTCUT_ENABLED=1' "$INSTALL_DIR/install.conf" >/dev/null ||
  fail "legacy shortcut migration should persist its result"

output="$("$COMMAND" --help)"
[[ "$output" == *"Elo — Minecraft instance manager"* ]] ||
  fail "the installed command did not display help"

ELO_HOME="$TEST_ROOT/data" "$COMMAND" help instances activate >/dev/null

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

"$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" --no-shortcut >/dev/null
[[ ! -e "$SHORTCUT" ]] || fail "--no-shortcut should remove the managed shortcut"

"$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" \
  --configure-shortcut >/dev/null
[[ -f "$SHORTCUT" ]] || fail "--configure-shortcut should recreate the shortcut"

"$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" \
  --terminal warp-terminal >/dev/null
WARP_CONFIG="$XDG_DATA_HOME/warp-terminal/launch_configurations/elo-cli.yaml"
[[ -f "$WARP_CONFIG" ]] || fail "Warp selection should create a launch configuration"
"$INSTALL_DIR/current/lib/launcher.sh"
grep -Fx 'warp://launch/Elo%20CLI' "$OPEN_LOG" >/dev/null ||
  fail "Warp launcher should open Elo's launch configuration URI"

"$PROJECT_DIR/install.sh" --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" --terminal kitty >/dev/null
[[ -f "$SHORTCUT" ]] || fail "terminal override should recreate the shortcut"
[[ ! -e "$WARP_CONFIG" ]] || fail "changing terminals should remove Elo's Warp configuration"

MAC_INSTALL_DIR="$TEST_ROOT/mac install root"
MAC_BIN_DIR="$TEST_ROOT/mac bin"
MAC_APPLICATIONS_DIR="$TEST_ROOT/mac applications"
MAC_SHORTCUT="$MAC_APPLICATIONS_DIR/Elo.app"
cat >"$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
chmod +x "$FAKE_BIN/uname"
ELO_APPLICATIONS_DIR="$MAC_APPLICATIONS_DIR" "$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" --install-dir "$MAC_INSTALL_DIR" \
  --bin-dir "$MAC_BIN_DIR" >/dev/null
[[ -d "$MAC_SHORTCUT" ]] || fail "macOS installation should create Elo.app"
[[ -x "$MAC_SHORTCUT/Contents/MacOS/Elo" ]] ||
  fail "macOS application bundle should contain an executable"
[[ -f "$MAC_SHORTCUT/Contents/Info.plist" ]] ||
  fail "macOS application bundle should contain Info.plist"
grep -Fx 'Managed by the Elo installer.' \
  "$MAC_SHORTCUT/Contents/Resources/.elo-managed" >/dev/null ||
  fail "macOS application bundle should be marked as installer-managed"
grep -F '<string>io.github.3nderxp.elo</string>' \
  "$MAC_SHORTCUT/Contents/Info.plist" >/dev/null ||
  fail "macOS application bundle should define Elo's bundle identifier"
"$MAC_SHORTCUT/Contents/MacOS/Elo"
sed -n '1p' "$OPEN_LOG" | grep -Fx -- '-a' >/dev/null ||
  fail "macOS launcher should use open's application option"
sed -n '2p' "$OPEN_LOG" | grep -Fx 'Terminal' >/dev/null ||
  fail "macOS launcher should select Apple Terminal"
sed -n '3p' "$OPEN_LOG" | grep -Fx "$MAC_INSTALL_DIR/current/elo.sh" >/dev/null ||
  fail "macOS launcher should open Elo's active command"
ELO_APPLICATIONS_DIR="$MAC_APPLICATIONS_DIR" "$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" --install-dir "$MAC_INSTALL_DIR" \
  --bin-dir "$MAC_BIN_DIR" --no-shortcut >/dev/null
[[ ! -e "$MAC_SHORTCUT" ]] ||
  fail "--no-shortcut should remove the installer-managed macOS application"
rm "$FAKE_BIN/uname"

printf 'ok 1 - local installation creates and updates a working command\n'

mkdir -p "$FAKE_REMOTE/v1.2.3" "$FAKE_REMOTE/v2.0.0-rc.1"
cp "$PROJECT_DIR/install.sh" "$FAKE_REMOTE/v1.2.3/install.sh"
cp "$PROJECT_DIR/elo.sh" "$FAKE_REMOTE/v1.2.3/elo.sh"
cp -R "$PROJECT_DIR/lib" "$FAKE_REMOTE/v1.2.3/lib"
cp -R "$PROJECT_DIR/assets" "$FAKE_REMOTE/v1.2.3/assets"
cp "$PROJECT_DIR/install.sh" "$FAKE_REMOTE/v2.0.0-rc.1/install.sh"
cp "$PROJECT_DIR/elo.sh" "$FAKE_REMOTE/v2.0.0-rc.1/elo.sh"
cp -R "$PROJECT_DIR/lib" "$FAKE_REMOTE/v2.0.0-rc.1/lib"
cp -R "$PROJECT_DIR/assets" "$FAKE_REMOTE/v2.0.0-rc.1/assets"

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

SELF_HOME="$TEST_ROOT/self-data"
SELF_MINECRAFT="$TEST_ROOT/self-minecraft"
mkdir -p "$SELF_MINECRAFT/mods"
printf 'original\n' >"$SELF_MINECRAFT/mods/original.txt"
ELO_HOME="$SELF_HOME" "$COMMAND" init --minecraft-path "$SELF_MINECRAFT" >/dev/null
ELO_HOME="$SELF_HOME" "$COMMAND" instances create alpha >/dev/null
ELO_HOME="$SELF_HOME" "$COMMAND" instances activate alpha --yes >/dev/null
ELO_HOME="$SELF_HOME" "$COMMAND" uninstall --yes >/dev/null
[[ ! -e "$COMMAND" && ! -L "$COMMAND" ]] ||
  fail "self-uninstall should remove the Elo command"
[[ ! -e "$SHORTCUT" ]] ||
  fail "self-uninstall should remove the installer-managed shortcut"
[[ -d "$SELF_HOME/instances/alpha" ]] ||
  fail "self-uninstall should preserve instance data by default"
[[ -f "$SELF_MINECRAFT/mods/original.txt" ]] ||
  fail "self-uninstall should restore original Minecraft directories"
[[ -x "$FAKE_BIN/gum" ]] ||
  fail "self-uninstall should preserve externally supplied Gum"

printf 'ok 4 - self-uninstall restores links and preserves data by default\n'

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
GUM_PRIVATE="$(awk -F= '$1 == "GUM_PATH" { print $2 }' "$GUM_INSTALL_DIR/install.conf")"
[[ -f "$GUM_PRIVATE" && ! -L "$GUM_PRIVATE" && -x "$GUM_PRIVATE" ]] ||
  fail "installer should create a private Gum executable"
[[ ! -e "$GUM_BIN/gum" && ! -L "$GUM_BIN/gum" ]] ||
  fail "installer should not expose Gum as a global command"
[[ "$("$GUM_PRIVATE")" == "gum test fixture" ]] ||
  fail "installed Gum command should execute the verified artifact"

printf 'ok 5 - installer downloads and verifies Gum in user space\n'

mkdir -p "$GUM_ROOT/data"
mkdir -p "$GUM_ROOT/minecraft"
ELO_HOME="$GUM_ROOT/data" "$GUM_BIN/elo" init \
  --minecraft-path "$GUM_ROOT/minecraft" >/dev/null
ln -s "$GUM_PRIVATE" "$GUM_BIN/gum"
ELO_HOME="$GUM_ROOT/data" "$GUM_BIN/elo" uninstall --purge --yes >/dev/null
[[ ! -e "$GUM_BIN/elo" && ! -L "$GUM_BIN/elo" ]] ||
  fail "self-uninstall should remove the Elo command"
[[ -f "$GUM_BIN/gum" && ! -L "$GUM_BIN/gum" && -x "$GUM_BIN/gum" ]] ||
  fail "self-uninstall should preserve a legacy global Gum command"
[[ "$("$GUM_BIN/gum")" == "gum test fixture" ]] ||
  fail "preserved legacy Gum should remain functional"
[[ ! -e "$GUM_INSTALL_DIR" ]] ||
  fail "self-uninstall should remove the installation root"
[[ ! -e "$GUM_ROOT/data" ]] ||
  fail "self-uninstall --purge should remove ELO_HOME"

printf 'ok 6 - purge removes private Gum and preserves legacy global Gum\n'
printf '1..6\n'
