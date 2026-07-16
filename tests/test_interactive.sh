#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elo-interactive-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

ELO_HOME="$TEST_ROOT/elo-home"
ELO_CONFIG_FILE="$ELO_HOME/config.conf"
ELO_STATE_FILE="$ELO_HOME/state.conf"
ELO_INSTANCES_DIR="$ELO_HOME/instances"
ELO_BACKUP_DIR="$ELO_HOME/backups/original"
ELO_DEFAULT_MANAGED_FOLDERS="mods resourcepacks shaderpacks config"
ELO_GUM_COMMAND="test-gum"

# shellcheck source=../lib/utils.sh
source "$PROJECT_DIR/lib/utils.sh"
# shellcheck source=../lib/config.sh
source "$PROJECT_DIR/lib/config.sh"
# shellcheck source=../lib/provider.sh
source "$PROJECT_DIR/lib/provider.sh"
# shellcheck source=../lib/interactive.sh
source "$PROJECT_DIR/lib/interactive.sh"

mkdir -p -- "$ELO_INSTANCES_DIR/alpha"
: >"$ELO_CONFIG_FILE"
elo_config_set ACTIVE_INSTANCE alpha
elo_config_set PREFERRED_PROVIDER modrinth

RESPONSES="$TEST_ROOT/responses"
CALLS="$TEST_ROOT/calls"
MENUS="$TEST_ROOT/menus"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1" expected="$2"
  grep -F -- "$expected" "$file" >/dev/null || fail "$file does not contain '$expected'"
}

assert_call() {
  local expected="$1" actual
  actual="$(cat "$CALLS")"
  [[ "$actual" == "$expected" ]] || {
    printf 'expected call:\n%s\nactual call:\n%s\n' "$expected" "$actual" >&2
    fail "interactive command arguments differ"
  }
}

elo_test_queue() {
  : >"$RESPONSES"
  while (($# > 0)); do
    printf '%s\n' "$1" >>"$RESPONSES"
    shift
  done
}

elo_test_response() {
  local response temp
  response="$(sed -n '1p' "$RESPONSES")"
  temp="$RESPONSES.tmp"
  sed '1d' "$RESPONSES" >"$temp"
  mv -- "$temp" "$RESPONSES"
  printf '%s\n' "$response"
}

elo_ui_choose_header() {
  printf '%s\n' "$*" >>"$MENUS"
  elo_test_response
}

elo_ui_input() {
  elo_test_response
}

elo_ui_confirm() {
  [[ "$(elo_test_response)" == "yes" ]]
}

elo_provider_available_names() {
  printf '%s\n' modrinth
}

elo_test_record() {
  : >"$CALLS"
  while (($# > 0)); do
    printf '%s\n' "$1" >>"$CALLS"
    shift
  done
}

elo_cmd_search() { elo_test_record search "$@"; }
elo_cmd_install() { elo_test_record install "$@"; }
elo_cmd_adopt() { elo_test_record adopt "$@"; }
elo_cmd_addon_remove() { elo_test_record remove "$@"; }
elo_cmd_link() { elo_test_record activate "$@"; }
elo_cmd_provider() { elo_test_record provider "$@"; }
elo_cmd_update() { elo_test_record update "$@"; }
elo_cmd_uninstall() { elo_test_record uninstall "$@"; }

elo_test_queue sodium Mod alpha "Use preferred (modrinth)" 25
elo_ui_search
assert_call $'search\nsodium\n--limit\n25\n--type\nmod\n--instance\nalpha'

elo_test_queue alpha sodium "Use preferred (modrinth)" "Preview only (dry run)"
elo_ui_install
assert_call $'install\nalpha\nsodium\n--dry-run'

elo_test_queue alpha "Replace existing directories permanently"
elo_ui_activate
assert_call $'activate\nalpha\n--mode\nreplace'

elo_test_queue alpha mods/manual.jar
elo_ui_adopt
assert_call $'adopt\nalpha\nmods/manual.jar'

elo_test_queue alpha "Exact relative file path" mods/manual.jar yes
elo_ui_remove_addon
assert_call $'remove\nalpha\n--file\nmods/manual.jar\n--remove-orphans'

elo_test_queue "Change preferred provider" modrinth
elo_ui_provider
assert_call $'provider\nset\nmodrinth'

elo_test_queue "Specific version" v1.2.3
elo_ui_update
assert_call $'update\n--version\nv1.2.3'

elo_test_queue "Uninstall and permanently delete all data"
elo_ui_uninstall
assert_call $'uninstall\n--purge'

: >"$MENUS"
elo_test_queue Back
elo_ui_instances_menu
elo_test_queue Back
elo_ui_addons_menu
elo_test_queue Back
elo_ui_system_menu
elo_test_queue Addons Back
elo_ui_help
elo_test_queue Instances Back
elo_ui_help

for label in \
  "Create instance" "Activate or switch instance" "Reset managed links" \
  "Search addons" "Install addon" "Adopt external addon" "Remove addon" \
  "Provider settings" "Status" "Update Elo" "Uninstall Elo" \
  "Search Install List Adopt Remove Provider" \
  "Create Activate Reset List Remove"; do
  assert_contains "$MENUS" "$label"
done

printf 'ok 1 - interactive UI delegates all CLI operations and options\n'
