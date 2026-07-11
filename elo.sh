#!/usr/bin/env bash

set -euo pipefail

ELO_ENTRYPOINT="${BASH_SOURCE[0]}"
while [[ -L "$ELO_ENTRYPOINT" ]]; do
  ELO_ENTRYPOINT_DIR="$(cd -- "$(dirname -- "$ELO_ENTRYPOINT")" && pwd -P)"
  ELO_LINK_TARGET="$(readlink "$ELO_ENTRYPOINT")"
  if [[ "$ELO_LINK_TARGET" == /* ]]; then
    ELO_ENTRYPOINT="$ELO_LINK_TARGET"
  else
    ELO_ENTRYPOINT="$ELO_ENTRYPOINT_DIR/$ELO_LINK_TARGET"
  fi
done
ELO_SCRIPT_DIR="$(cd -- "$(dirname -- "$ELO_ENTRYPOINT")" && pwd -P)"
unset ELO_ENTRYPOINT ELO_ENTRYPOINT_DIR ELO_LINK_TARGET

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
# shellcheck source=lib/update.sh
source "$ELO_SCRIPT_DIR/lib/update.sh"
# shellcheck source=lib/provider_modrinth.sh
source "$ELO_SCRIPT_DIR/lib/provider_modrinth.sh"
# shellcheck source=lib/provider.sh
source "$ELO_SCRIPT_DIR/lib/provider.sh"

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
    update) elo_cmd_update "$@" ;;
    provider) elo_cmd_provider "$@" ;;
    search) elo_cmd_search "$@" ;;
    install) elo_cmd_install "$@" ;;
    addons) elo_cmd_addons "$@" ;;
    adopt) elo_cmd_adopt "$@" ;;
    uninstall) elo_cmd_uninstall "$@" ;;
    help) elo_help_command "${1:-}" ;;
    --help | -h) elo_help_general ;;
    *)
      elo_error "Unknown command: $command"
      elo_help_general >&2
      return 2
      ;;
  esac
}

main "$@"
