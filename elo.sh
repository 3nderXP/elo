#!/usr/bin/env bash

set -euo pipefail

ELO_ENTRYPOINT="${BASH_SOURCE[0]}"
ELO_COMMAND_DIR="$(cd -- "$(dirname -- "$ELO_ENTRYPOINT")" && pwd -P)"
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
# shellcheck source=lib/self.sh
source "$ELO_SCRIPT_DIR/lib/self.sh"
# shellcheck source=lib/provider_modrinth.sh
source "$ELO_SCRIPT_DIR/lib/provider_modrinth.sh"
# shellcheck source=lib/provider.sh
source "$ELO_SCRIPT_DIR/lib/provider.sh"
# shellcheck source=lib/interactive.sh
source "$ELO_SCRIPT_DIR/lib/interactive.sh"

elo_dispatch_instances() {
  local action="${1:-}"
  [[ -n "$action" ]] && shift
  if [[ "$action" != "help" && ("${1:-}" == "--help" || "${1:-}" == "-h") ]]; then
    elo_help_instances "$action"
    return
  fi
  case "$action" in
    create) elo_cmd_new "$@" ;;
    activate) elo_cmd_link "$@" ;;
    reset) elo_cmd_reset "$@" ;;
    list) elo_cmd_list "$@" ;;
    remove) elo_cmd_remove "$@" ;;
    help | --help | -h | "") elo_help_instances "${1:-}" ;;
    *) elo_error "Unknown instances command: $action"; elo_help_instances >&2; return 2 ;;
  esac
}

elo_dispatch_addons() {
  local action="${1:-}"
  [[ -n "$action" ]] && shift
  if [[ "$action" != "help" && ("${1:-}" == "--help" || "${1:-}" == "-h") ]]; then
    elo_help_addons "$action"
    return
  fi
  case "$action" in
    search) elo_cmd_search "$@" ;;
    install) elo_cmd_install "$@" ;;
    list) elo_cmd_addons_list "$@" ;;
    adopt) elo_cmd_adopt "$@" ;;
    remove) elo_cmd_addon_remove "$@" ;;
    provider) elo_cmd_provider "$@" ;;
    help | --help | -h | "") elo_help_addons "${1:-}" ;;
    *) elo_error "Unknown addons command: $action"; elo_help_addons >&2; return 2 ;;
  esac
}

main() {
  local command
  if (($# == 0)); then
    elo_ui_run
    return
  fi
  command="$1"
  if (($# > 0)); then
    shift
  fi

  if [[ "$command" != "help" && "$command" != "instances" && "$command" != "addons" && ("${1:-}" == "--help" || "${1:-}" == "-h") ]]; then
    elo_help_command "$command"
    return
  fi

  case "$command" in
    init) elo_cmd_init "$@" ;;
    instances) elo_dispatch_instances "$@" ;;
    addons) elo_dispatch_addons "$@" ;;
    status) elo_cmd_status "$@" ;;
    update) elo_cmd_update "$@" ;;
    uninstall) elo_cmd_uninstall "$@" ;;
    help) elo_help_command "$@" ;;
    --help | -h) elo_help_general ;;
    *)
      elo_error "Unknown command: $command"
      elo_help_general >&2
      return 2
      ;;
  esac
}

main "$@"
