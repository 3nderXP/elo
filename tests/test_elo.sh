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
  [[ -f "$1" ]] || fail "arquivo esperado: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "caminho deveria estar ausente: $1"
}

assert_contains() {
  local text="$1"
  local expected="$2"
  [[ "$text" == *"$expected"* ]] || fail "texto não contém '$expected'"
}

assert_link_target() {
  local link="$1"
  local expected="$2"
  [[ -L "$link" ]] || fail "symlink esperado: $link"
  [[ "$(readlink "$link")" == "$expected" ]] || fail "destino incorreto para $link"
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

  "$ELO" new alpha --version 1.20.1 --loader fabric >/dev/null
  "$ELO" new beta --version 1.21 --loader neoforge >/dev/null
  printf 'alpha\n' >"$ELO_HOME/instances/alpha/mods/alpha.txt"
  printf 'beta\n' >"$ELO_HOME/instances/beta/mods/beta.txt"

  output="$("$ELO" list)"
  assert_contains "$output" "alpha"
  assert_contains "$output" "1.20.1"

  "$ELO" link alpha --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  assert_file "$ELO_HOME/backups/original/mods.bak/original.txt"

  "$ELO" switch beta --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/beta/mods"
  assert_file "$ELO_HOME/backups/original/mods.bak/original.txt"

  output="$("$ELO" status)"
  assert_contains "$output" "Instância ativa: beta"
  assert_contains "$output" "backed_up"

  "$ELO" reset --yes >/dev/null
  assert_file "$MINECRAFT_PATH/mods/original.txt"
  [[ ! -L "$MINECRAFT_PATH/mods" ]] || fail "mods não deveria continuar como symlink"
  assert_absent "$MINECRAFT_PATH/resourcepacks"

  pass "link, switch e reset preservam o estado original"
}

test_replace_mode() {
  setup_environment replace
  mkdir -p -- "$MINECRAFT_PATH/config"
  printf 'original\n' >"$MINECRAFT_PATH/config/options.txt"
  "$ELO" new replace-test >/dev/null

  "$ELO" link replace-test --mode replace --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/config" "$ELO_HOME/instances/replace-test/config"
  assert_absent "$ELO_HOME/backups/original/config.bak"

  "$ELO" reset --yes >/dev/null
  assert_absent "$MINECRAFT_PATH/config"

  pass "modo replace não cria restauração inexistente"
}

test_foreign_symlink_is_protected() {
  local foreign="$TEST_ROOT/foreign-target"
  setup_environment foreign-link
  mkdir -p -- "$foreign"
  ln -s -- "$foreign" "$MINECRAFT_PATH/mods"
  "$ELO" new alpha >/dev/null

  if "$ELO" link alpha --yes >/dev/null 2>&1; then
    fail "link externo deveria impedir ativação"
  fi
  assert_link_target "$MINECRAFT_PATH/mods" "$foreign"

  pass "symlink externo nunca é removido"
}

test_remove_requires_reset() {
  setup_environment remove
  "$ELO" new alpha >/dev/null
  "$ELO" link alpha --yes >/dev/null

  if "$ELO" remove alpha --yes >/dev/null 2>&1; then
    fail "instância ativa não deveria ser removida sem --reset"
  fi
  "$ELO" remove alpha --reset --yes >/dev/null
  assert_absent "$ELO_HOME/instances/alpha"

  pass "remoção de instância ativa exige reset"
}

test_paths_with_spaces() {
  setup_environment "paths with spaces"
  mkdir -p -- "$MINECRAFT_PATH/mods"
  printf 'original\n' >"$MINECRAFT_PATH/mods/original.txt"
  "$ELO" new alpha >/dev/null

  "$ELO" link alpha --yes >/dev/null
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  "$ELO" reset --yes >/dev/null
  assert_file "$MINECRAFT_PATH/mods/original.txt"

  pass "caminhos com espaços são preservados"
}

test_help_is_explicit() {
  local output

  output="$("$ELO" --help)"
  assert_contains "$output" "<valor>  obrigatório"
  assert_contains "$output" "[valor]  opcional"
  assert_contains "$output" "elo help <comando>"

  output="$("$ELO" new --help)"
  assert_contains "$output" "Campos obrigatórios:"
  assert_contains "$output" "Campos opcionais:"
  assert_contains "$output" "<nome-instancia>"
  assert_contains "$output" "Padrão: vanilla"

  output="$("$ELO" help link)"
  assert_contains "$output" "backup"
  assert_contains "$output" "replace"
  assert_contains "$output" "Não é reversível"

  pass "ajuda diferencia campos e explica efeitos"
}

test_confirmation_is_required() {
  setup_environment confirmation
  "$ELO" new alpha >/dev/null

  if "$ELO" link alpha >/dev/null 2>&1; then
    fail "ativação não interativa deveria exigir --yes"
  fi
  assert_absent "$MINECRAFT_PATH/mods"

  "$ELO" link alpha --yes >/dev/null
  if "$ELO" reset >/dev/null 2>&1; then
    fail "reset não interativo deveria exigir --yes"
  fi
  assert_link_target "$MINECRAFT_PATH/mods" "$ELO_HOME/instances/alpha/mods"
  "$ELO" reset --yes >/dev/null

  pass "operações de estado exigem confirmação"
}

test_instance_lifecycle
test_replace_mode
test_foreign_symlink_is_protected
test_remove_requires_reset
test_paths_with_spaces
test_help_is_explicit
test_confirmation_is_required

printf '1..%d\n' "$pass_count"
