#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-install-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

INSTALL_DIR="$TEST_ROOT/install root"
BIN_DIR="$TEST_ROOT/bin"
COMMAND="$BIN_DIR/elo"
export PATH="$BIN_DIR:$PATH"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

"$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" \
  --bin-dir "$BIN_DIR" >/dev/null

[[ -L "$INSTALL_DIR/current" ]] || fail "current should be a symlink"
[[ -L "$COMMAND" ]] || fail "the elo command should be a symlink"
[[ -x "$COMMAND" ]] || fail "the elo command should be executable"

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
printf '1..1\n'
