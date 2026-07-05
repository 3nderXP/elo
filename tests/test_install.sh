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

[[ -L "$INSTALL_DIR/current" ]] || fail "current deveria ser um symlink"
[[ -L "$COMMAND" ]] || fail "o comando elo deveria ser um symlink"
[[ -x "$COMMAND" ]] || fail "o comando elo deveria ser executável"

output="$("$COMMAND" --help)"
[[ "$output" == *"Elo — gerenciador"* ]] ||
  fail "o comando instalado não executou a ajuda"

ELO_HOME="$TEST_ROOT/data" "$COMMAND" help link >/dev/null

first_release="$(readlink "$INSTALL_DIR/current")"
"$PROJECT_DIR/install.sh" \
  --source "$PROJECT_DIR" \
  --install-dir "$INSTALL_DIR" \
  --bin-dir "$BIN_DIR" >/dev/null
second_release="$(readlink "$INSTALL_DIR/current")"

[[ "$first_release" != "$second_release" ]] ||
  fail "uma reinstalação deveria ativar uma nova versão"
"$COMMAND" --help >/dev/null ||
  fail "o comando deveria continuar funcional após reinstalação"

printf 'ok 1 - instalação local cria e atualiza um comando funcional\n'
printf '1..1\n'
