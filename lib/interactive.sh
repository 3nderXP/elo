#!/usr/bin/env bash

ELO_UI_ACCENT="212"
ELO_GUM_COMMAND=""
ELO_UI_PAGE_SIZE=10
ELO_UI_SKIP_PAUSE=0

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

elo_ui_choose_header() {
  local header="$1"
  shift
  "$ELO_GUM_COMMAND" choose --header "$header" --cursor "› " \
    --cursor.foreground "$ELO_UI_ACCENT" --selected.foreground "$ELO_UI_ACCENT" \
    --height 14 "$@"
}

elo_ui_input() {
  local prompt="$1" placeholder="${2:-}" value="${3:-}"
  "$ELO_GUM_COMMAND" input --prompt "$prompt: " --prompt.foreground "$ELO_UI_ACCENT" \
    --placeholder "$placeholder" --value "$value" --width 60
}

elo_ui_confirm() {
  "$ELO_GUM_COMMAND" confirm --prompt.foreground "$ELO_UI_ACCENT" \
    --selected.background "$ELO_UI_ACCENT" "$1"
}

elo_ui_paginate() {
  local title="$1" header_count="$2" output="$3"
  local page=0 data_count total_pages start end index action
  local -a lines actions
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done <<<"$output"

  data_count=$((${#lines[@]} - header_count))
  ((data_count < 0)) && data_count=0
  total_pages=$(((data_count + ELO_UI_PAGE_SIZE - 1) / ELO_UI_PAGE_SIZE))
  ((total_pages == 0)) && total_pages=1
  ELO_UI_SKIP_PAUSE=1

  while true; do
    clear
    elo_ui_header
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_ACCENT" --bold \
      "$title — Page $((page + 1)) of $total_pages"
    printf '\n'
    index=0
    while ((index < header_count && index < ${#lines[@]})); do
      printf '%s\n' "${lines[$index]}"
      index=$((index + 1))
    done
    start=$((header_count + page * ELO_UI_PAGE_SIZE))
    end=$((start + ELO_UI_PAGE_SIZE))
    ((end > ${#lines[@]})) && end=${#lines[@]}
    index=$start
    while ((index < end)); do
      printf '%s\n' "${lines[$index]}"
      index=$((index + 1))
    done
    printf '\n'

    actions=()
    ((page > 0)) && actions+=("Previous")
    ((page + 1 < total_pages)) && actions+=("Next")
    actions+=("Back")
    action="$(elo_ui_choose_header "Navigate results" "${actions[@]}")" || return 0
    case "$action" in
      Previous) page=$((page - 1)) ;;
      Next) page=$((page + 1)) ;;
      *) return 0 ;;
    esac
  done
}

elo_ui_paginated_command() {
  local title="$1" header_count="$2" output
  shift 2
  if ! output="$("$@")"; then
    return 1
  fi
  elo_ui_paginate "$title" "$header_count" "$output"
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
  elo_ui_choose_header "$header" "${ELO_UI_INSTANCES[@]}"
}

elo_ui_select_provider() {
  local header="${1:-Select a provider}" preferred provider selection
  local -a options
  preferred="$(elo_preferred_provider)"
  elo_ui_providers
  options=("Use preferred ($preferred)")
  for provider in "${ELO_UI_PROVIDERS[@]}"; do
    [[ "$provider" == "$preferred" ]] || options+=("$provider")
  done
  selection="$(elo_ui_choose_header "$header" "${options[@]}")" || return
  if [[ "$selection" == "Use preferred ($preferred)" ]]; then
    printf '%s\n' ""
  else
    printf '%s\n' "$selection"
  fi
}

elo_ui_providers() {
  local provider
  ELO_UI_PROVIDERS=()
  while IFS= read -r provider || [[ -n "$provider" ]]; do
    [[ -n "$provider" ]] && ELO_UI_PROVIDERS+=("$provider")
  done < <(elo_provider_available_names)
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
  loader="$(elo_ui_choose_header "Loader" fabric neoforge forge quilt vanilla)" || return 0
  elo_cmd_new "$name" --version "$version" --loader "$loader"
}

elo_ui_activate() {
  local instance mode selection
  instance="$(elo_ui_select_instance "Select the instance to activate")" || return 0
  selection="$(elo_ui_choose_header "How should existing Minecraft directories be handled?" \
    "Back up existing directories (recommended)" \
    "Replace existing directories permanently")" || return 0
  case "$selection" in
    "Back up existing directories (recommended)") mode="backup" ;;
    *) mode="replace" ;;
  esac
  elo_cmd_link "$instance" --mode "$mode"
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

elo_ui_search() {
  local query type_choice type="" instance_choice instance="" provider limit default_filter
  local -a args
  query="$(elo_ui_input "Search query" "sodium")" || return 0
  [[ -n "$query" ]] || return 0
  type_choice="$(elo_ui_choose_header "Addon type" "Any type" "Mod" "Resource pack" "Shader")" || return 0
  case "$type_choice" in
    Mod) type="mod" ;;
    "Resource pack") type="resourcepack" ;;
    Shader) type="shader" ;;
  esac

  elo_ui_instances
  if ((${#ELO_UI_INSTANCES[@]} > 0)); then
    if [[ -n "$(elo_active_instance)" ]]; then
      default_filter="Use active instance (default)"
    else
      default_filter="No instance filter (default)"
    fi
    instance_choice="$(elo_ui_choose_header "Compatibility filters" \
      "$default_filter" "${ELO_UI_INSTANCES[@]}")" || return 0
    case "$instance_choice" in
      "$default_filter") ;;
      *) instance="$instance_choice" ;;
    esac
  fi
  provider="$(elo_ui_select_provider "Search provider")" || return 0
  limit="$(elo_ui_input "Maximum results (1-100)" "50" "50")" || return 0
  [[ -n "$limit" ]] || limit=50

  args=("$query" --limit "$limit")
  [[ -n "$type" ]] && args+=(--type "$type")
  [[ -n "$instance" ]] && args+=(--instance "$instance")
  [[ -n "$provider" ]] && args+=(--provider "$provider")
  elo_ui_paginated_command "Search results" 1 elo_cmd_search "${args[@]}"
}

elo_ui_install() {
  local instance addon provider mode
  local -a args
  instance="$(elo_ui_select_instance "Install into which instance?")" || return 0
  addon="$(elo_ui_input "Addon ID or slug" "sodium")" || return 0
  [[ -n "$addon" ]] || return 0
  provider="$(elo_ui_select_provider "Installation provider")" || return 0
  mode="$(elo_ui_choose_header "Installation mode" "Install addon" "Preview only (dry run)")" || return 0
  args=("$instance" "$addon")
  [[ -n "$provider" ]] && args+=(--provider "$provider")
  [[ "$mode" == "Preview only (dry run)" ]] && args+=(--dry-run)
  elo_cmd_install "${args[@]}"
}

elo_ui_addons_list() {
  local instance
  instance="$(elo_ui_select_instance "Show addons from which instance?")" || return 0
  elo_ui_paginated_command "Addons in $instance" 2 elo_cmd_addons_list "$instance"
}

elo_ui_adopt() {
  local instance relative
  instance="$(elo_ui_select_instance "Adopt a file from which instance?")" || return 0
  relative="$(elo_ui_input "Relative addon path" "mods/example.jar")" || return 0
  [[ -n "$relative" ]] || return 0
  elo_cmd_adopt "$instance" "$relative"
}

elo_ui_remove_addon() {
  local instance target addon="" relative="" provider="" remove_orphans=0
  local -a args
  instance="$(elo_ui_select_instance "Remove an addon from which instance?")" || return 0
  target="$(elo_ui_choose_header "How should the addon be identified?" \
    "Provider ID or slug" "Exact relative file path")" || return 0
  case "$target" in
    "Provider ID or slug")
      addon="$(elo_ui_input "Managed addon ID or slug")" || return 0
      [[ -n "$addon" ]] || return 0
      provider="$(elo_ui_select_provider "Addon provider")" || return 0
      ;;
    *)
      relative="$(elo_ui_input "Relative addon path" "mods/example.jar")" || return 0
      [[ -n "$relative" ]] || return 0
      ;;
  esac
  if elo_ui_confirm "Also remove verified orphan dependencies?"; then
    remove_orphans=1
  fi
  args=("$instance")
  if [[ -n "$relative" ]]; then args+=(--file "$relative"); else args+=("$addon"); fi
  [[ -n "$provider" ]] && args+=(--provider "$provider")
  ((remove_orphans == 1)) && args+=(--remove-orphans)
  elo_cmd_addon_remove "${args[@]}"
}

elo_ui_provider() {
  local action provider
  action="$(elo_ui_choose_header "Provider settings" \
    "Show preferred provider" "List available providers" "Change preferred provider" "Back")" || return 0
  case "$action" in
    "Show preferred provider") elo_cmd_provider show ;;
    "List available providers")
      elo_ui_paginated_command "Available providers" 1 elo_cmd_provider list
      ;;
    "Change preferred provider")
      elo_ui_providers
      if ((${#ELO_UI_PROVIDERS[@]} == 0)); then
        elo_warn "No providers are available."
        return 0
      fi
      provider="$(elo_ui_choose_header "New preferred provider" "${ELO_UI_PROVIDERS[@]}")" || return 0
      elo_cmd_provider set "$provider"
      ;;
  esac
}

elo_ui_update() {
  local mode version
  mode="$(elo_ui_choose_header "Elo release" "Latest stable release" "Specific version" "Back")" || return 0
  case "$mode" in
    "Latest stable release") elo_cmd_update ;;
    "Specific version")
      version="$(elo_ui_input "Release version" "v0.4.0")" || return 0
      [[ -n "$version" ]] && elo_cmd_update --version "$version"
      ;;
  esac
}

elo_ui_uninstall() {
  local mode
  mode="$(elo_ui_choose_header "Uninstall Elo" \
    "Uninstall and preserve instance data" "Uninstall and permanently delete all data" "Back")" || return 0
  case "$mode" in
    "Uninstall and preserve instance data") elo_cmd_uninstall ;;
    "Uninstall and permanently delete all data") elo_cmd_uninstall --purge ;;
    *) return 1 ;;
  esac
}

elo_ui_help_instances() {
  local topic
  topic="$(elo_ui_choose_header "Instances help" Create Activate Reset List Remove Back)" || return 0
  case "$topic" in
    Create) elo_help_instances create ;;
    Activate) elo_help_instances activate ;;
    Reset) elo_help_instances reset ;;
    List) elo_help_instances list ;;
    Remove) elo_help_instances remove ;;
  esac
}

elo_ui_help_addons() {
  local topic
  topic="$(elo_ui_choose_header "Addons help" Search Install List Adopt Remove Provider Back)" || return 0
  case "$topic" in
    Search) elo_help_addons search ;;
    Install) elo_help_addons install ;;
    List) elo_help_addons list ;;
    Adopt) elo_help_addons adopt ;;
    Remove) elo_help_addons remove ;;
    Provider) elo_help_addons provider ;;
  esac
}

elo_ui_help() {
  local topic
  topic="$(elo_ui_choose_header "Help topic" General Init Instances Addons Status Update Uninstall Back)" || return 0
  case "$topic" in
    General) elo_help_general ;;
    Init) elo_help_init ;;
    Instances) elo_ui_help_instances ;;
    Addons) elo_ui_help_addons ;;
    Status) elo_help_status ;;
    Update) elo_help_update ;;
    Uninstall) elo_help_uninstall ;;
  esac
}

elo_ui_instances_menu() {
  local action
  action="$(elo_ui_choose_header "Instances" \
    "Create instance" "Activate or switch instance" "List instances" \
    "Reset managed links" "Remove instance" "Back")" || return 0
  case "$action" in
    "Create instance") elo_ui_new ;;
    "Activate or switch instance") elo_ui_activate ;;
    "List instances") elo_ui_paginated_command "Instances" 1 elo_cmd_list ;;
    "Reset managed links") elo_cmd_reset ;;
    "Remove instance") elo_ui_remove_instance ;;
  esac
}

elo_ui_addons_menu() {
  local action
  action="$(elo_ui_choose_header "Addons" \
    "Search addons" "Install addon" "List addons" "Adopt external addon" \
    "Remove addon" "Provider settings" "Back")" || return 0
  case "$action" in
    "Search addons") elo_ui_search ;;
    "Install addon") elo_ui_install ;;
    "List addons") elo_ui_addons_list ;;
    "Adopt external addon") elo_ui_adopt ;;
    "Remove addon") elo_ui_remove_addon ;;
    "Provider settings") elo_ui_provider ;;
  esac
}

elo_ui_system_menu() {
  local action
  action="$(elo_ui_choose_header "System" "Status" "Update Elo" "Uninstall Elo" "Back")" || return 0
  case "$action" in
    Status) elo_cmd_status ;;
    "Update Elo") elo_ui_update ;;
    "Uninstall Elo")
      if elo_ui_uninstall; then
        ELO_UI_EXIT=1
      fi
      ;;
  esac
}

elo_ui_run() {
  local action
  ELO_UI_EXIT=0
  elo_ui_require || return

  while true; do
    ELO_UI_SKIP_PAUSE=0
    clear
    elo_ui_header
    if [[ ! -f "$ELO_CONFIG_FILE" ]]; then
      action="$(elo_ui_choose "Initialize Elo" "Update Elo" "Uninstall Elo" "Help" "Exit")" || return 0
      case "$action" in
        "Initialize Elo") elo_ui_init || true ;;
        "Update Elo") elo_ui_update || true ;;
        "Uninstall Elo") if elo_ui_uninstall; then return 0; fi ;;
        Help) elo_ui_help ;;
        Exit) return 0 ;;
      esac
    else
      action="$(elo_ui_choose "Instances" "Addons" "System" "Help" "Exit")" || return 0
      case "$action" in
        Instances) elo_ui_instances_menu || true ;;
        Addons) elo_ui_addons_menu || true ;;
        System) elo_ui_system_menu || true ;;
        Help) elo_ui_help ;;
        Exit) return 0 ;;
      esac
    fi
    [[ "$ELO_UI_EXIT" == "1" ]] && return 0
    if [[ "$ELO_UI_SKIP_PAUSE" != "1" ]]; then
      elo_ui_pause
    fi
  done
}
