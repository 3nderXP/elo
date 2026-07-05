#!/usr/bin/env bash

set -euo pipefail

ELO_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=lib/utils.sh
source "$ELO_SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/help.sh
source "$ELO_SCRIPT_DIR/lib/help.sh"
# shellcheck source=lib/config.sh
source "$ELO_SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/instance.sh
source "$ELO_SCRIPT_DIR/lib/instance.sh"
# shellcheck source=lib/link.sh
source "$ELO_SCRIPT_DIR/lib/link.sh"

main() {
  local command="${1:-help}"
  if (($# > 0)); then
    shift
  fi

  if [[ "$command" != "help" && ("${1:-}" == "--help" || "${1:-}" == "-h") ]]; then
    elo_help_command "$command"
    return
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
    help) elo_help_command "${1:-}" ;;
    --help | -h) elo_help_general ;;
    *)
      elo_error "Comando desconhecido: $command"
      elo_help_general >&2
      return 2
      ;;
  esac
}

main "$@"
