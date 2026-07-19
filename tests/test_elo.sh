#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ELO="$PROJECT_DIR/elo.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

pass_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'ok %d - %s\n' "$pass_count" "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "path should be absent: $1"
}

assert_contains() {
  local text="$1"
  local expected="$2"
  [[ "$text" == *"$expected"* ]] || fail "text does not contain '$expected'"
}

assert_link_target() {
  local link="$1"
  local expected="$2"
  [[ -L "$link" ]] || fail "expected symlink: $link"
  [[ "$(readlink "$link")" == "$expected" ]] || fail "incorrect target for $link"
}

setup_environment() {
  local name="$1"
  export ELO_HOME="$TEST_ROOT/$name/elo-home"
  MINECRAFT_PATH="$TEST_ROOT/$name/minecraft"
  mkdir -p -- "$MINECRAFT_PATH"
  "$ELO" init --minecraft-path "$MINECRAFT_PATH" >/dev/null
}

test_instance_lifecycle() {
  local output
  setup_environment lifecycle

  mkdir -p -- "$MINECRAFT_PATH/mods"
  printf 'original\n' >"$MINECRAFT_PATH/mods/original.txt"
  mkdir -p -- "$MINECRAFT_PATH/saves/OriginalWorld"
  printf 'level\n' >"$MINECRAFT_PATH/saves/OriginalWorld/level.dat"

  "$ELO" instances create alpha --version 1.20.1 --loader fabric >/dev/null
  "$ELO" instances create beta --version 1.21 --loader neoforge >/dev/null
  printf 'alpha\n' >"$ELO_HOME/instances/alpha/mods/alpha.txt"
  printf 'beta\n' >"$ELO_HOME/instances/beta/mods/beta.txt"

  output="$("$ELO" instances list)"
  assert_contains "$output" "alpha"
  assert_contains "$output" "1.20.1"

  "$ELO" instances activate alpha --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  assert_file "$ELO_HOME/backups/original/mods.bak/original.txt"
  assert_link_target "$MINECRAFT_PATH/saves" "$ELO_HOME/instances/alpha/saves"
  assert_file "$ELO_HOME/backups/original/saves.bak/OriginalWorld/level.dat"

  "$ELO" instances activate beta --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/beta/mods"
  assert_file "$ELO_HOME/backups/original/mods.bak/original.txt"

  output="$("$ELO" status)"
  assert_contains "$output" "Active instance: beta"
  assert_contains "$output" "backed_up"

  "$ELO" instances reset --yes >/dev/null
  assert_file "$MINECRAFT_PATH/mods/original.txt"
  assert_file "$MINECRAFT_PATH/saves/OriginalWorld/level.dat"
  [[ ! -L "$MINECRAFT_PATH/mods" ]] || fail "mods should no longer be a symlink"
  assert_absent "$MINECRAFT_PATH/resourcepacks"

  pass "link, switch, and reset preserve the original state"
}

test_replace_mode() {
  setup_environment replace
  mkdir -p -- "$MINECRAFT_PATH/config"
  printf 'original\n' >"$MINECRAFT_PATH/config/options.txt"
  "$ELO" instances create replace-test >/dev/null

  "$ELO" instances activate replace-test --mode replace --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/config" "$ELO_HOME/instances/replace-test/config"
  assert_absent "$ELO_HOME/backups/original/config.bak"

  "$ELO" instances reset --yes >/dev/null
  assert_absent "$MINECRAFT_PATH/config"

  pass "replace mode does not create unavailable restoration data"
}

test_foreign_symlink_is_protected() {
  local foreign="$TEST_ROOT/foreign-target"
  setup_environment foreign-link
  mkdir -p -- "$foreign"
  ln -s -- "$foreign" "$MINECRAFT_PATH/mods"
  "$ELO" instances create alpha >/dev/null

  if "$ELO" instances activate alpha --yes >/dev/null 2>&1; then
    fail "external symlink should prevent activation"
  fi
  assert_link_target "$MINECRAFT_PATH/mods" "$foreign"

  pass "external symlink is never removed"
}

test_remove_requires_reset() {
  setup_environment remove
  "$ELO" instances create alpha >/dev/null
  "$ELO" instances activate alpha --yes >/dev/null

  if "$ELO" instances remove alpha --yes >/dev/null 2>&1; then
    fail "active instance should not be removed without --reset"
  fi
  "$ELO" instances remove alpha --reset --yes >/dev/null
  assert_absent "$ELO_HOME/instances/alpha"

  pass "removing an active instance requires reset"
}

test_paths_with_spaces() {
  setup_environment "paths with spaces"
  mkdir -p -- "$MINECRAFT_PATH/mods"
  printf 'original\n' >"$MINECRAFT_PATH/mods/original.txt"
  "$ELO" instances create alpha >/dev/null

  "$ELO" instances activate alpha --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  "$ELO" instances reset --yes >/dev/null
  assert_file "$MINECRAFT_PATH/mods/original.txt"

  pass "paths containing spaces are preserved"
}

test_help_is_explicit() {
  local output

  output="$("$ELO" --help)"
  assert_contains "$output" "<value>  required"
  assert_contains "$output" "[value]  optional"
  assert_contains "$output" "elo help <command>"
  assert_contains "$output" "interactive interface"

  output="$("$ELO" instances create --help)"
  assert_contains "$output" "<name>"
  assert_contains "$output" "vanilla"

  output="$("$ELO" help instances activate)"
  assert_contains "$output" "backup"
  assert_contains "$output" "replace"
  assert_contains "$output" "permanently removes"

  output="$("$ELO" help update)"
  assert_contains "$output" "latest stable"
  assert_contains "$output" "exact SemVer"
  assert_contains "$output" "--version <version>"

  pass "help distinguishes fields and explains effects"
}

test_legacy_commands_are_removed() {
  local output

  if output="$("$ELO" new alpha 2>&1)"; then
    fail "legacy instance command should be rejected"
  fi
  assert_contains "$output" "Unknown command: new"
  if output="$("$ELO" install alpha sodium 2>&1)"; then
    fail "legacy addon command should be rejected"
  fi
  assert_contains "$output" "Unknown command: install"
  if output="$("$ELO" uninstall alpha sodium 2>&1)"; then
    fail "root uninstall should never accept addon arguments"
  fi
  assert_contains "$output" "Usage: elo uninstall"
  if output="$("$ELO" uninstall --yes 2>&1)"; then
    fail "self-uninstall should refuse a source checkout"
  fi
  assert_contains "$output" "only from an installed Elo release"

  pass "legacy flat commands are rejected"
}

test_interactive_mode_requires_terminal() {
  local output

  if output="$("$ELO" 2>&1)"; then
    fail "interactive mode should refuse non-terminal input"
  fi
  assert_contains "$output" "Interactive mode requires a terminal"

  pass "no-argument mode is reserved for an interactive terminal"
}

test_confirmation_is_required() {
  setup_environment confirmation
  "$ELO" instances create alpha >/dev/null

  if "$ELO" instances activate alpha >/dev/null 2>&1; then
    fail "non-interactive activation should require --yes"
  fi
  assert_absent "$MINECRAFT_PATH/mods"

  "$ELO" instances activate alpha --yes >/dev/null
  if "$ELO" instances reset >/dev/null 2>&1; then
    fail "non-interactive reset should require --yes"
  fi
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  "$ELO" instances reset --yes >/dev/null

  pass "state-changing operations require confirmation"
}

test_instance_lifecycle
test_replace_mode
test_foreign_symlink_is_protected
test_remove_requires_reset
test_paths_with_spaces
test_help_is_explicit
test_confirmation_is_required
test_interactive_mode_requires_terminal
test_legacy_commands_are_removed

printf '1..%d\n' "$pass_count"
