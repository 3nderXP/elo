#!/usr/bin/env bash

set -euo pipefail

elo_launcher_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

elo_launcher_config_get() {
  local file="$1" wanted="$2" key value
  while IFS='=' read -r key value; do
    if [[ "$key" == "$wanted" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done <"$file"
  return 1
}

elo_launcher_main() {
  local script_dir release_dir install_root config terminal mode command_path
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  release_dir="$(dirname "$script_dir")"
  install_root="$(dirname "$(dirname "$release_dir")")"
  config="$install_root/install.conf"
  command_path="$install_root/current/elo.sh"

  [[ -f "$config" && -x "$command_path" ]] ||
    elo_launcher_die "The Elo installation is incomplete."
  terminal="$(elo_launcher_config_get "$config" TERMINAL_COMMAND || true)"
  mode="$(elo_launcher_config_get "$config" TERMINAL_MODE || true)"
  [[ -n "$terminal" && -x "$terminal" ]] ||
    elo_launcher_die "The configured terminal is no longer available. Reinstall Elo to choose another one."

  case "$mode" in
    warp)
      exec "$terminal" 'warp://launch/Elo%20CLI'
      ;;
    double-dash) exec "$terminal" -- "$command_path" ;;
    dash-e) exec "$terminal" -e "$command_path" ;;
    direct) exec "$terminal" "$command_path" ;;
    xfce) exec "$terminal" --command="$command_path" ;;
    wezterm) exec "$terminal" start -- "$command_path" ;;
    *) elo_launcher_die "Unsupported terminal launch mode: $mode" ;;
  esac
}

elo_launcher_main "$@"
