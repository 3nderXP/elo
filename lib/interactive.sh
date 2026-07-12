#!/usr/bin/env bash

ELO_UI_ACCENT="212"
ELO_GUM_COMMAND=""

elo_ui_require() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    elo_die "Interactive mode requires a terminal. Run 'elo --help' for commands."
    return 1
  fi
  ELO_GUM_COMMAND="$(elo_gum_command || true)"
  if [[ -z "$ELO_GUM_COMMAND" ]]; then
    elo_die "Interactive mode requires gum. Install it from https://github.com/charmbracelet/gum"
    return 1
  fi
}

elo_ui_header() {
  local active=""
  [[ -f "$ELO_CONFIG_FILE" ]] && active="$(elo_active_instance)"
  "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_ACCENT" --bold --border rounded \
    --border-foreground "$ELO_UI_ACCENT" --padding "0 2" \
    "Elo" "Minecraft instance manager"
  if [[ -n "$active" ]]; then
    "$ELO_GUM_COMMAND" style --foreground 245 "Active instance: $active"
  fi
  printf '\n'
}

elo_ui_pause() {
  printf '\n'
  "$ELO_GUM_COMMAND" input --placeholder "Press Enter to return to the menu" --prompt "" >/dev/null || true
}

elo_ui_choose() {
  "$ELO_GUM_COMMAND" choose --cursor "› " --cursor.foreground "$ELO_UI_ACCENT" \
    --selected.foreground "$ELO_UI_ACCENT" --height 14 "$@"
}

elo_ui_input() {
  local prompt="$1" placeholder="${2:-}" value="${3:-}"
  "$ELO_GUM_COMMAND" input --prompt "$prompt: " --prompt.foreground "$ELO_UI_ACCENT" \
    --placeholder "$placeholder" --value "$value" --width 60
}

elo_ui_instances() {
  local directory
  ELO_UI_INSTANCES=()
  shopt -s nullglob
  for directory in "$ELO_INSTANCES_DIR"/*; do
    [[ -d "$directory" ]] && ELO_UI_INSTANCES+=("${directory##*/}")
  done
  shopt -u nullglob
}

elo_ui_select_instance() {
  local header="${1:-Select an instance}"
  elo_ui_instances
  if ((${#ELO_UI_INSTANCES[@]} == 0)); then
    elo_warn "No instances found."
    return 1
  fi
  "$ELO_GUM_COMMAND" choose --header "$header" --cursor "› " \
    --cursor.foreground "$ELO_UI_ACCENT" "${ELO_UI_INSTANCES[@]}"
}

elo_ui_init() {
  local path
  path="$(elo_ui_input "Minecraft directory" "$HOME/.minecraft" "$HOME/.minecraft")" || return 0
  [[ -n "$path" ]] || return 0
  elo_cmd_init --minecraft-path "$path"
}

elo_ui_new() {
  local name version loader
  name="$(elo_ui_input "Instance name" "fabric-1_21")" || return 0
  [[ -n "$name" ]] || return 0
  version="$(elo_ui_input "Minecraft version" "1.21" "unknown")" || return 0
  loader="$("$ELO_GUM_COMMAND" choose --header "Loader" fabric neoforge forge quilt vanilla)" || return 0
  elo_cmd_new "$name" --version "$version" --loader "$loader"
}

elo_ui_activate() {
  local instance
  instance="$(elo_ui_select_instance "Select the instance to activate")" || return 0
  elo_cmd_link "$instance"
}

elo_ui_install() {
  local instance addon
  instance="$(elo_ui_select_instance "Install into which instance?")" || return 0
  addon="$(elo_ui_input "Modrinth ID or slug" "sodium")" || return 0
  [[ -n "$addon" ]] || return 0
  elo_cmd_install "$instance" "$addon"
}

elo_ui_addons() {
  local instance
  instance="$(elo_ui_select_instance "Show addons from which instance?")" || return 0
  elo_cmd_addons_list "$instance"
}

elo_ui_uninstall() {
  local instance addon
  instance="$(elo_ui_select_instance "Remove an addon from which instance?")" || return 0
  addon="$(elo_ui_input "Managed addon ID or slug")" || return 0
  [[ -n "$addon" ]] || return 0
  elo_cmd_addon_remove "$instance" "$addon"
}

elo_ui_remove_instance() {
  local instance active
  instance="$(elo_ui_select_instance "Permanently remove which instance?")" || return 0
  active="$(elo_active_instance)"
  if [[ "$instance" == "$active" ]]; then
    elo_cmd_remove "$instance" --reset
  else
    elo_cmd_remove "$instance"
  fi
}

elo_ui_run() {
  local action
  elo_ui_require || return

  while true; do
    clear
    elo_ui_header
    if [[ ! -f "$ELO_CONFIG_FILE" ]]; then
      action="$(elo_ui_choose "Initialize Elo" "Uninstall Elo" "Help" "Exit")" || return 0
      case "$action" in
        "Initialize Elo") elo_ui_init || true ;;
        "Uninstall Elo") if elo_cmd_uninstall; then return 0; fi ;;
        Help) elo_help_general ;;
        Exit) return 0 ;;
      esac
    else
      action="$(elo_ui_choose \
        "Switch instance" "Create instance" "Install addon" "View addons" \
        "Uninstall addon" "List instances" "Status" "Reset links" \
        "Remove instance" "Update Elo" "Uninstall Elo" "Help" "Exit")" || return 0
      case "$action" in
        "Switch instance") elo_ui_activate || true ;;
        "Create instance") elo_ui_new || true ;;
        "Install addon") elo_ui_install || true ;;
        "View addons") elo_ui_addons || true ;;
        "Uninstall addon") elo_ui_uninstall || true ;;
        "List instances") elo_cmd_list || true ;;
        Status) elo_cmd_status || true ;;
        "Reset links") elo_cmd_reset || true ;;
        "Remove instance") elo_ui_remove_instance || true ;;
        "Update Elo") elo_cmd_update || true ;;
        "Uninstall Elo") if elo_cmd_uninstall; then return 0; fi ;;
        Help) elo_help_general ;;
        Exit) return 0 ;;
      esac
    fi
    elo_ui_pause
  done
}
