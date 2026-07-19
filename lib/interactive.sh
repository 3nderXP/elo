#!/usr/bin/env bash

ELO_UI_GRASS="#84A66A"
ELO_UI_WOOD="#9A7252"
ELO_UI_SKY="#78A9C4"
ELO_UI_TEXT="#F1F3EE"
ELO_UI_MUTED="#9AA7A0"
ELO_UI_DARK="#18211B"
ELO_GUM_COMMAND=""
ELO_UI_PAGE_SIZE=10
ELO_UI_SKIP_PAUSE=0
ELO_UI_ACTIVE=0
ELO_UI_CACHE_DIR=""
ELO_UI_CACHE_ROOT=""
ELO_UI_CACHE_PIDS=""

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
  ELO_UI_CACHE_ROOT="${TMPDIR:-/tmp}"
  [[ "$ELO_UI_CACHE_ROOT" == "/" ]] || ELO_UI_CACHE_ROOT="${ELO_UI_CACHE_ROOT%/}"
  ELO_UI_CACHE_DIR="$(mktemp -d "$ELO_UI_CACHE_ROOT/elo-ui.XXXXXX")" || {
    elo_die "Could not create the interactive cache."
    return 1
  }
  trap elo_ui_cleanup EXIT
}

elo_ui_header() {
  local active="" columns="" logo_file logo="" logo_width=0 required_columns=0
  [[ -f "$ELO_CONFIG_FILE" ]] && active="$(elo_active_instance)"
  logo_file="${ELO_SCRIPT_DIR:-}/assets/branding/elo.asc"
  columns="${COLUMNS:-}"
  if [[ -z "$columns" ]] && command -v tput >/dev/null 2>&1; then
    columns="$(tput cols 2>/dev/null || true)"
  fi
  [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
  if [[ -r "$logo_file" ]]; then
    logo="$(<"$logo_file")"
    logo_width="$(awk 'length > width { width = length } END { print width + 0 }' "$logo_file")"
    required_columns=$((logo_width + 14))
  fi
  if [[ -n "$logo" && "$columns" -ge "$required_columns" ]]; then
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_WOOD" --bold \
      --background "$ELO_UI_DARK" --border rounded \
      --border-foreground "$ELO_UI_GRASS" --border-background "$ELO_UI_DARK" \
      --padding "1 6" \
      "$logo"
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_SKY" --bold \
      "Minecraft instance manager"
  else
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_SKY" --background "$ELO_UI_DARK" \
      --bold --border rounded --border-foreground "$ELO_UI_GRASS" \
      --border-background "$ELO_UI_DARK" --padding "1 6" \
      "Elo" "Minecraft instance manager"
  fi
  if [[ -n "$active" ]]; then
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_GRASS" "Active instance: $active"
  fi
  printf '\n'
}

elo_ui_pause() {
  printf '\n'
  "$ELO_GUM_COMMAND" input --placeholder "Press Enter to return to the menu" --prompt "" >/dev/null || true
}

elo_ui_choose() {
  "$ELO_GUM_COMMAND" choose --cursor "› " --cursor.foreground "$ELO_UI_GRASS" \
    --header.foreground "$ELO_UI_SKY" --selected.foreground "$ELO_UI_TEXT" \
    --selected.background "$ELO_UI_WOOD" --height 14 "$@"
}

elo_ui_choose_header() {
  local header="$1"
  shift
  "$ELO_GUM_COMMAND" choose --header "$header" --cursor "› " \
    --cursor.foreground "$ELO_UI_GRASS" --header.foreground "$ELO_UI_SKY" \
    --selected.foreground "$ELO_UI_TEXT" --selected.background "$ELO_UI_WOOD" \
    --height 14 "$@"
}

elo_ui_choose_header_selected() {
  local header="$1" selected="$2"
  shift 2
  "$ELO_GUM_COMMAND" choose --header "$header" --selected "$selected" \
    --cursor "› " --cursor.foreground "$ELO_UI_GRASS" \
    --header.foreground "$ELO_UI_SKY" --selected.foreground "$ELO_UI_TEXT" \
    --selected.background "$ELO_UI_WOOD" --height 14 "$@"
}

elo_ui_input() {
  local prompt="$1" placeholder="${2:-}" value="${3:-}"
  "$ELO_GUM_COMMAND" input --prompt "$prompt: " --prompt.foreground "$ELO_UI_GRASS" \
    --placeholder.foreground "$ELO_UI_MUTED" --cursor.foreground "$ELO_UI_SKY" \
    --placeholder "$placeholder" --value "$value" --width 60
}

elo_ui_confirm() {
  "$ELO_GUM_COMMAND" confirm --prompt.foreground "$ELO_UI_SKY" \
    --selected.foreground "$ELO_UI_DARK" --selected.background "$ELO_UI_GRASS" "$1"
}

elo_ui_file() {
  local header="$1" directory="$2"
  header="$header (↑↓ navigate · → enter folder · ← parent folder · Enter select · Esc cancel)"
  "$ELO_GUM_COMMAND" file "$directory" --file \
    --header "$header" --height 0 --show-help --all --cursor "› " \
    --cursor.foreground "$ELO_UI_GRASS" --header.foreground "$ELO_UI_SKY" \
    --directory.foreground "$ELO_UI_SKY" --symlink.foreground "$ELO_UI_WOOD" \
    --selected.foreground "$ELO_UI_TEXT" --selected.background "$ELO_UI_WOOD" \
    --permissions.foreground "$ELO_UI_MUTED" --file-size.foreground "$ELO_UI_MUTED"
}

elo_ui_render_table() {
  local source="$1" header_count="$2" widths="$3" table_file tab
  table_file="$ELO_UI_CACHE_DIR/render-table.tsv"
  tab=$'\t'
  awk -v header_count="$header_count" -v widths="$widths" '
    BEGIN { count = split(widths, width, ",") }
    NR > 1 && NR <= header_count { next }
    {
      start = 1
      for (column = 1; column <= count; column++) {
        if (width[column] == 0) value = substr($0, start)
        else value = substr($0, start, width[column])
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        printf "%s%s", column == 1 ? "" : "\t", value
        start += width[column] + 1
      }
      printf "\n"
    }
  ' "$source" >"$table_file"
  elo_ui_render_tsv_table "$table_file"
}

elo_ui_render_tsv_table() {
  local table_file="$1" tab
  tab=$'\t'
  "$ELO_GUM_COMMAND" table --print --file "$table_file" --separator "$tab" \
    --border rounded --border.foreground "$ELO_UI_SKY" \
    --header.foreground "$ELO_UI_GRASS" --header.background "$ELO_UI_DARK" \
    --cell.foreground "$ELO_UI_TEXT" --cell.background "$ELO_UI_DARK"
}

elo_ui_install_plan_table() {
  local instance="$1" addon="$2" lines="$3" table_file
  table_file="$ELO_UI_CACHE_DIR/install-plan.tsv"
  printf 'KIND\tNAME\tVERSION\tTYPE\tACTION\n%s\n' "$lines" >"$table_file"
  "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_SKY" --bold \
    "Installation plan for $addon in $instance"
  printf '\n'
  elo_ui_render_tsv_table "$table_file"
}

elo_ui_status_table() {
  local lines="$1" table_file
  table_file="$ELO_UI_CACHE_DIR/status.tsv"
  printf 'FOLDER\tLINK\tORIGINAL\tSTATE\n%s\n' "$lines" >"$table_file"
  elo_ui_render_tsv_table "$table_file"
}

elo_ui_navigation_action() {
  local preferred="$1" option selected=""
  shift
  for option in "$@"; do
    [[ "$option" == "$preferred" ]] && selected="$preferred"
  done
  if [[ -z "$selected" ]]; then
    case "$preferred" in
      Next | Last)
        for option in "$@"; do [[ "$option" == "Previous" ]] && selected=Previous; done
        ;;
      Previous | First)
        for option in "$@"; do [[ "$option" == "Next" ]] && selected=Next; done
        ;;
    esac
  fi
  [[ -n "$selected" ]] || selected="$1"
  elo_ui_choose_header_selected "Navigate results" "$selected" "$@"
}

elo_ui_cleanup() {
  [[ -n "$ELO_UI_CACHE_DIR" && -n "$ELO_UI_CACHE_ROOT" ]] || return 0
  elo_ui_cache_stop_jobs
  case "$ELO_UI_CACHE_DIR" in
    "$ELO_UI_CACHE_ROOT"/elo-ui.*) rm -rf -- "$ELO_UI_CACHE_DIR" ;;
  esac
  ELO_UI_CACHE_DIR=""
  ELO_UI_ACTIVE=0
}

elo_ui_cache_stop_jobs() {
  local pid
  for pid in $ELO_UI_CACHE_PIDS; do
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
  done
  ELO_UI_CACHE_PIDS=""
}

elo_ui_cache_forget_pid() {
  local forgotten="$1" pid remaining=""
  for pid in $ELO_UI_CACHE_PIDS; do
    [[ "$pid" == "$forgotten" ]] && continue
    remaining="$remaining $pid"
  done
  ELO_UI_CACHE_PIDS="$remaining"
}

elo_ui_cache_reset() {
  local entry
  [[ -n "$ELO_UI_CACHE_DIR" && -d "$ELO_UI_CACHE_DIR" ]] || {
    elo_die "Interactive cache is not available."
    return 1
  }
  elo_ui_cache_stop_jobs
  for entry in "$ELO_UI_CACHE_DIR"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    rm -f -- "$entry"
  done
}

elo_ui_wait_for_status() {
  local title="$1" status_file="$2" pid="$3"
  if ! "$ELO_GUM_COMMAND" spin --spinner dot \
    --spinner.foreground "$ELO_UI_GRASS" --title.foreground "$ELO_UI_SKY" \
    --title "$title" -- sh -c \
    'while [ ! -f "$1" ]; do sleep 0.1; done' sh "$status_file"; then
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
    return 1
  fi
  wait "$pid" >/dev/null 2>&1 || true
}

elo_ui_cache_page() {
  local snapshot="$1" header_count="$2" page="$3"
  local target="$ELO_UI_CACHE_DIR/page-$page" temporary start end
  [[ -f "$target" ]] && return 0
  temporary="$target.tmp"
  : >"$temporary"
  if ((header_count > 0)); then
    sed -n "1,${header_count}p" "$snapshot" >>"$temporary"
  fi
  start=$((header_count + page * ELO_UI_PAGE_SIZE + 1))
  end=$((start + ELO_UI_PAGE_SIZE - 1))
  sed -n "${start},${end}p" "$snapshot" >>"$temporary"
  mv -- "$temporary" "$target"
}

elo_ui_cache_adjacent_pages() {
  local snapshot="$1" header_count="$2" page="$3" total_pages="$4"
  elo_ui_cache_page "$snapshot" "$header_count" "$page" || return
  if ((page > 0)); then
    elo_ui_cache_page "$snapshot" "$header_count" "$((page - 1))" || return
  fi
  if ((page + 1 < total_pages)); then
    elo_ui_cache_page "$snapshot" "$header_count" "$((page + 1))" || return
  fi
}

elo_ui_paginate_snapshot() {
  local title="$1" header_count="$2" snapshot="$3" widths="$4"
  local page=0 line_count data_count total_pages action last_action=Next
  local -a actions
  line_count="$(wc -l <"$snapshot")"
  data_count=$((line_count - header_count))
  ((data_count < 0)) && data_count=0
  total_pages=$(((data_count + ELO_UI_PAGE_SIZE - 1) / ELO_UI_PAGE_SIZE))
  ((total_pages == 0)) && total_pages=1
  ELO_UI_SKIP_PAUSE=1

  while true; do
    clear
    elo_ui_header
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_SKY" --bold \
      "$title — Page $((page + 1)) of $total_pages"
    printf '\n'
    elo_ui_cache_adjacent_pages "$snapshot" "$header_count" "$page" "$total_pages" || return
    elo_ui_render_table "$ELO_UI_CACHE_DIR/page-$page" "$header_count" "$widths"
    printf '\n'

    actions=()
    if ((page > 0)); then actions+=("First" "Previous"); fi
    if ((page + 1 < total_pages)); then actions+=("Next" "Last"); fi
    actions+=("Back")
    action="$(elo_ui_navigation_action "$last_action" "${actions[@]}")" || return 0
    last_action="$action"
    case "$action" in
      First) page=0 ;;
      Previous) page=$((page - 1)) ;;
      Next) page=$((page + 1)) ;;
      Last) page=$((total_pages - 1)) ;;
      *) return 0 ;;
    esac
  done
}

elo_ui_paginate() {
  local title="$1" header_count="$2" widths="$3" output="$4" snapshot
  elo_ui_cache_reset || return
  snapshot="$ELO_UI_CACHE_DIR/snapshot"
  printf '%s\n' "$output" >"$snapshot"
  elo_ui_paginate_snapshot "$title" "$header_count" "$snapshot" "$widths"
}

elo_ui_run_with_spinner() {
  local title="$1" snapshot="$2" errors="$3" status_file="$4" status_temp pid status
  shift 4
  status_temp="$status_file.tmp"
  (
    if "$@" >"$snapshot" 2>"$errors"; then
      status=0
    else
      status=$?
    fi
    printf '%s\n' "$status" >"$status_temp"
    mv -- "$status_temp" "$status_file"
  ) &
  pid=$!
  elo_ui_wait_for_status "$title" "$status_file" "$pid" || return
  status="$(sed -n '1p' "$status_file")"
  [[ -s "$errors" ]] && cat -- "$errors" >&2
  [[ "$status" == "0" ]]
}

elo_ui_lazy_page_start() {
  local page="$1" page_size="$2" loader="$3" target temporary errors status_file status_temp status pid
  shift 3
  target="$ELO_UI_CACHE_DIR/page-$page"
  [[ -f "$target" || -f "$target.loading" ]] && return 0
  temporary="$target.tmp"
  errors="$target.errors"
  status_file="$target.status"
  status_temp="$status_file.tmp"
  : >"$target.loading"
  (
    if "$loader" "$page" "$page_size" "$@" >"$temporary" 2>"$errors"; then
      status=0
      mv -- "$temporary" "$target"
    else
      status=$?
      rm -f -- "$temporary"
    fi
    printf '%s\n' "$status" >"$status_temp"
    mv -- "$status_temp" "$status_file"
  ) &
  pid=$!
  printf '%s\n' "$pid" >"$target.pid"
  ELO_UI_CACHE_PIDS="$ELO_UI_CACHE_PIDS $pid"
}

elo_ui_lazy_page_ensure() {
  local title="$1" page="$2" page_size="$3" loader="$4" target pid status
  shift 4
  target="$ELO_UI_CACHE_DIR/page-$page"
  [[ -f "$target" ]] && return 0
  elo_ui_lazy_page_start "$page" "$page_size" "$loader" "$@" || return
  pid="$(sed -n '1p' "$target.pid")"
  if ! elo_ui_wait_for_status "Loading $title page $((page + 1))..." "$target.status" "$pid"; then
    elo_ui_cache_forget_pid "$pid"
    return 1
  fi
  elo_ui_cache_forget_pid "$pid"
  status="$(sed -n '1p' "$target.status")"
  [[ -s "$target.errors" ]] && cat -- "$target.errors" >&2
  rm -f -- "$target.loading" "$target.pid" "$target.status" "$target.errors"
  [[ "$status" == "0" && -f "$target" ]]
}

elo_ui_lazy_paginate() {
  local title="$1" item_count="$2" page_size="$3" header_count="$4" widths="$5" loader="$6"
  local page=0 total_pages action last_action=Next
  local -a actions
  shift 6
  total_pages=$(((item_count + page_size - 1) / page_size))
  ((total_pages == 0)) && total_pages=1
  ELO_UI_SKIP_PAUSE=1
  while true; do
    elo_ui_lazy_page_ensure "$title" "$page" "$page_size" "$loader" "$@" || return
    clear
    elo_ui_header
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_SKY" --bold \
      "$title — Page $((page + 1)) of $total_pages"
    printf '\n'
    elo_ui_render_table "$ELO_UI_CACHE_DIR/page-$page" "$header_count" "$widths"
    printf '\n'
    ((page > 0)) && elo_ui_lazy_page_start "$((page - 1))" "$page_size" "$loader" "$@"
    ((page + 1 < total_pages)) && elo_ui_lazy_page_start "$((page + 1))" "$page_size" "$loader" "$@"
    actions=()
    if ((page > 0)); then actions+=("First" "Previous"); fi
    if ((page + 1 < total_pages)); then actions+=("Next" "Last"); fi
    actions+=("Back")
    action="$(elo_ui_navigation_action "$last_action" "${actions[@]}")" || return 0
    last_action="$action"
    case "$action" in
      First) page=0 ;;
      Previous) page=$((page - 1)) ;;
      Next) page=$((page + 1)) ;;
      Last) page=$((total_pages - 1)) ;;
      *) elo_ui_cache_stop_jobs; return 0 ;;
    esac
  done
}

elo_ui_addons_page_loader() {
  local page="$1" page_size="$2" instance="$3" inventory="$4"
  elo_addons_list_inventory_page "$instance" "$inventory" "$((page * page_size))" "$page_size"
}

elo_ui_search_page_loader() {
  local page="$1" page_size="$2" provider="$3" query="$4" type="$5" instance="$6"
  local response total results total_temp
  response="$(elo_search_page "$provider" "$query" "$type" "$instance" \
    "$page_size" "$((page * page_size))")" || return
  total="$(printf '%s\n' "$response" | sed -n '1p')"
  results="$(printf '%s\n' "$response" | sed -n '2,$p')"
  if ((page == 0)); then
    total_temp="$ELO_UI_CACHE_DIR/search-total.tmp"
    printf '%s\n' "$total" >"$total_temp"
    mv -- "$total_temp" "$ELO_UI_CACHE_DIR/search-total"
  fi
  printf '%-10s %-20s %-12s %-36s %s\n' ID SLUG TYPE NAME DOWNLOADS
  if [[ -z "$results" ]]; then
    elo_info "No addons found."
  else
    printf '%s\n' "$results" | while IFS=$'\t' read -r id slug result_type name downloads; do
      printf '%-10s %-20s %-12s %-36s %s\n' \
        "$id" "$slug" "$result_type" "$name" "$downloads"
    done
  fi
}

elo_ui_paginated_command() {
  local title="$1" header_count="$2" widths="$3" snapshot errors status_file
  shift 3
  elo_ui_cache_reset || return
  snapshot="$ELO_UI_CACHE_DIR/snapshot"
  errors="$ELO_UI_CACHE_DIR/errors"
  status_file="$ELO_UI_CACHE_DIR/status"
  if ! elo_ui_run_with_spinner "Loading $title..." "$snapshot" "$errors" "$status_file" "$@"; then
    return 1
  fi
  elo_ui_paginate_snapshot "$title" "$header_count" "$snapshot" "$widths"
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

elo_ui_import_mrpack() {
  local pack name
  pack="$(elo_ui_file "Select a Modrinth .mrpack file" "$HOME")" || return 0
  [[ -n "$pack" ]] || return 0
  name="$(elo_ui_input "New instance name" "fabric-modpack")" || return 0
  [[ -n "$name" ]] || return 0
  elo_cmd_import_mrpack "$name" "$pack"
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
  local query type_choice type="" instance_choice instance="" provider page_size default_filter total
  query="$(elo_ui_input "Search query" "sodium")" || return 0
  [[ -n "$query" ]] || return 0
  type_choice="$(elo_ui_choose_header "Addon type" "Any type" "Mod" "Modpack" "Resource pack" "Shader")" || return 0
  case "$type_choice" in
    Mod) type="mod" ;;
    Modpack) type="modpack" ;;
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
  provider="${provider:-$(elo_preferred_provider)}"
  instance="${instance:-$(elo_active_instance)}"
  page_size="$(elo_ui_input "Items per page (1-100)" "10" "10")" || return 0
  [[ -n "$page_size" ]] || page_size=10
  [[ "$page_size" =~ ^[0-9]+$ ]] && ((page_size >= 1 && page_size <= 100)) || {
    elo_warn "Page size must be between 1 and 100."
    return 1
  }

  elo_ui_cache_reset || return
  elo_ui_lazy_page_ensure "Search results" 0 "$page_size" elo_ui_search_page_loader \
    "$provider" "$query" "$type" "$instance" || return
  total="$(sed -n '1p' "$ELO_UI_CACHE_DIR/search-total")"
  [[ "$total" =~ ^[0-9]+$ ]] || {
    elo_die "Search provider returned an invalid total result count."
    return 1
  }
  elo_ui_lazy_paginate "Search results" "$total" "$page_size" \
    1 "10,20,12,36,0" elo_ui_search_page_loader "$provider" "$query" "$type" "$instance"
}

elo_ui_install() {
  local instance addon provider project_type platform_choice platform="" mode source
  local -a args
  instance="$(elo_ui_select_instance "Install into which instance?")" || return 0
  source="$(elo_ui_choose_header "Installation source" "Provider project" "Local .mrpack file")" || return 0
  if [[ "$source" == "Local .mrpack file" ]]; then
    addon="$(elo_ui_file "Select a Modrinth .mrpack file" "$HOME")" || return 0
    [[ -n "$addon" ]] || return 0
    provider="$(elo_preferred_provider)"
  else
    addon="$(elo_ui_input "Addon ID or slug" "sodium")" || return 0
    [[ -n "$addon" ]] || return 0
    provider="$(elo_ui_select_provider "Installation provider")" || return 0
    provider="${provider:-$(elo_preferred_provider)}"
    project_type="$(elo_provider_call "$provider" project_type "$addon")" || return 0
    if [[ "$project_type" == "shader" ]]; then
      platform_choice="$(elo_ui_choose_header "Shader platform" "Iris" "OptiFine")" || return 0
      case "$platform_choice" in
        Iris) platform="iris" ;;
        OptiFine) platform="optifine" ;;
      esac
    fi
  fi
  mode="$(elo_ui_choose_header "Installation mode" "Install addon" "Preview only (dry run)")" || return 0
  args=("$instance" "$addon")
  [[ -n "$platform" ]] && args+=(--platform "$platform")
  [[ "$source" != "Local .mrpack file" && "$provider" != "$(elo_preferred_provider)" ]] && args+=(--provider "$provider")
  [[ "$mode" == "Preview only (dry run)" ]] && args+=(--dry-run)
  elo_cmd_install "${args[@]}"
}

elo_ui_addons_list() {
  local instance inventory errors status_file item_count
  instance="$(elo_ui_select_instance "Show addons from which instance?")" || return 0
  elo_ui_cache_reset || return
  inventory="$ELO_UI_CACHE_DIR/inventory"
  errors="$ELO_UI_CACHE_DIR/errors"
  status_file="$ELO_UI_CACHE_DIR/status"
  elo_ui_run_with_spinner "Indexing addons in $instance..." \
    "$inventory" "$errors" "$status_file" elo_addons_list_inventory "$instance" || return
  item_count="$(wc -l <"$inventory")"
  elo_ui_lazy_paginate "Addons in $instance" "$item_count" "$ELO_UI_PAGE_SIZE" \
    2 "22,36,12,24,10,0" elo_ui_addons_page_loader "$instance" "$inventory"
}

elo_ui_select_addon_file() {
  local instance="$1" purpose="$2" category directory instance_directory selected
  instance_directory="$ELO_INSTANCES_DIR/$instance"
  category="$(elo_ui_choose_header "Addon category" "Mods" "Resource packs" "Shaders")" || return
  case "$category" in
    Mods) directory="mods" ;;
    "Resource packs") directory="resourcepacks" ;;
    Shaders) directory="shaderpacks" ;;
  esac
  selected="$(elo_ui_file "$purpose" "$instance_directory/$directory")" || return
  [[ -n "$selected" ]] || return 1
  case "$selected" in
    "$instance_directory/$directory"/*)
      printf '%s/%s\n' "$directory" "${selected#"$instance_directory/$directory"/}"
      ;;
    /*)
      elo_warn "The selected file is outside the addon directory."
      return 1
      ;;
    "$directory"/*) printf '%s\n' "$selected" ;;
    ./*) printf '%s/%s\n' "$directory" "${selected#./}" ;;
    *) printf '%s/%s\n' "$directory" "$selected" ;;
  esac
}

elo_ui_adopt() {
  local instance relative
  instance="$(elo_ui_select_instance "Adopt a file from which instance?")" || return 0
  relative="$(elo_ui_select_addon_file "$instance" "Select the external addon to adopt")" || return 0
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
      relative="$(elo_ui_select_addon_file "$instance" "Select the addon file to remove")" || return 0
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
      elo_ui_paginated_command "Available providers" 1 "0" elo_cmd_provider list
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
  topic="$(elo_ui_choose_header "Instances help" Create Import Activate Reset List Remove Back)" || return 0
  case "$topic" in
    Create) elo_help_instances create ;;
    Import) elo_help_instances import ;;
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
    "Create instance" "Import Modrinth modpack" "Activate or switch instance" "List instances" \
    "Reset managed links" "Remove instance" "Back")" || return 0
  case "$action" in
    "Create instance") elo_ui_new ;;
    "Import Modrinth modpack") elo_ui_import_mrpack ;;
    "Activate or switch instance") elo_ui_activate ;;
    "List instances") elo_ui_paginated_command "Instances" 1 "24,12,12,0" elo_cmd_list ;;
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
  ELO_UI_ACTIVE=1

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
