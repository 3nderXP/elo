#!/usr/bin/env bash

set -euo pipefail

ELO_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=lib/utils.sh
source "$ELO_SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/config.sh
source "$ELO_SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/instance.sh
source "$ELO_SCRIPT_DIR/lib/instance.sh"
# shellcheck source=lib/link.sh
source "$ELO_SCRIPT_DIR/lib/link.sh"

elo_usage() {
  cat <<'EOF'
Elo — gerenciador de instâncias de Minecraft

Uso:
  elo init --minecraft-path <caminho>
  elo new <nome> [--version <versão>] [--loader <loader>]
  elo link <nome> [--mode backup|replace] [--yes]
  elo switch <nome>
  elo reset
  elo list
  elo status
  elo remove <nome> [--reset] [--yes]
  elo help
EOF
}

main() {
  local command="${1:-help}"
  if (($# > 0)); then
    shift
  fi

  case "$command" in
    init) elo_cmd_init "$@" ;;
    new) elo_cmd_new "$@" ;;
    link) elo_cmd_link "$@" ;;
    switch) elo_cmd_switch "$@" ;;
    reset) elo_cmd_reset "$@" ;;
    list) elo_cmd_list "$@" ;;
    status) elo_cmd_status "$@" ;;
    remove) elo_cmd_remove "$@" ;;
    help | --help | -h) elo_usage ;;
    *)
      elo_error "Comando desconhecido: $command"
      elo_usage >&2
      return 2
      ;;
  esac
}

main "$@"
