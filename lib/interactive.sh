#!/usr/bin/env bash

ELO_UI_GRASS="#84A66A"
ELO_UI_WOOD="#9A7252"
ELO_UI_SKY="#78A9C4"
ELO_UI_TEXT="#F1F3EE"
ELO_UI_MUTED="#9AA7A0"
ELO_UI_DARK="#18211B"
ELO_UI_ALERT="#E8B339"
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
  local current_version="" version_label="development"
  [[ -f "$ELO_CONFIG_FILE" ]] && active="$(elo_active_instance)"
  if declare -F elo_get_current_version >/dev/null 2>&1; then
    current_version="$(elo_get_current_version)"
    if [[ "$current_version" != "unknown" ]]; then
      if declare -F elo_update_is_semver >/dev/null 2>&1 && elo_update_is_semver "$current_version"; then
        version_label="v${current_version#v}"
      else
        version_label="$current_version"
      fi
    fi
  fi
  "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_MUTED" --border rounded \
    --border-foreground "$ELO_UI_GRASS" --padding "0 1" \
    "$version_label"
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
  if [[ "${ELO_UPDATE_AVAILABLE:-0}" == "1" ]]; then
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_ALERT" \
      "Update available: ${ELO_LATEST_VERSION} (System > Update Elo)"
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
  if [[ "$widths" == "tsv" ]]; then
    awk -v header_count="$header_count" 'NR > 1 && NR <= header_count { next } { print }' \
      "$source" >"$table_file"
    elo_ui_render_tsv_table "$table_file"
    return
  fi
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
  printf 'ID\tSLUG\tTYPE\tNAME\tDOWNLOADS\n'
  if [[ -z "$results" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' - - - "No addons found." -
  else
    printf '%s\n' "$results" | while IFS=$'\t' read -r id slug result_type name downloads; do
      printf '%s\t%s\t%s\t%s\t%s\n' \
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

elo_ui_migration_report() {
  local instance="$1" current="$2" target="$3" plan="$4" report
  report="$ELO_UI_CACHE_DIR/migration-report.txt"
  {
    printf 'Instance: %s\nMinecraft: %s -> %s (%s)\n\n' \
      "$instance" "$current" "$target" "$(elo_version_relation "$current" "$target")"
    elo_migration_plan_print "$plan"
    printf '\nStates:\n'
    printf '  keep        current file already supports target\n'
    printf '  update      compatible replacement available\n'
    printf '  restore     managed file is missing; replacement available\n'
    printf '  unavailable no compatible release found\n'
    printf '  modified    file differs from registry; manual review required\n'
    printf '  collision   replacement filename already exists\n'
    printf '  unmanaged   provider/local file cannot be resolved\n'
    printf '  blocked     required dependency cannot migrate safely\n'
    printf '  external    unregistered file requires manual review\n'
  } >"$report"
  "$ELO_GUM_COMMAND" pager --no-soft-wrap --show-line-numbers <"$report"
}

elo_ui_migration_select_removals() {
  local plan="$1" options selected line key remove_keys=""
  options="$ELO_UI_CACHE_DIR/migration-incompatible.txt"
  : >"$options"
  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    [[ "$state" == unavailable || "$state" == unmanaged || "$state" == blocked ]] || continue
    printf '%s | %s | %s\n' "$key" "$state" "$name" >>"$options"
  done <"$plan"
  if [[ ! -s "$options" ]]; then
    elo_info "No removable incompatible addons found."
    return 0
  fi
  selected="$("$ELO_GUM_COMMAND" filter --no-limit --height 20 --show-help \
    --header "Select incompatible addons to REMOVE (Tab toggle · type to filter · Enter confirm)" \
    --placeholder "Filter by addon, source, or state" <"$options" || true)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    key="${line%% | *}"
    remove_keys="${remove_keys}${remove_keys:+,}$key"
  done <<<"$selected"
  printf '%s\n' "$remove_keys"
}

elo_ui_change_version() {
  local instance target current relation plan errors status choice remove_keys="" count=0
  instance="$(elo_ui_select_instance "Change version for which instance?")" || return 0
  current="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  target="$(elo_ui_input "New Minecraft version" "26.1.2" "$current")" || return 0
  [[ -n "$target" && "$target" != "$current" ]] || return 0
  relation="$(elo_version_relation "$current" "$target")"
  elo_warn "Minecraft version $relation: $current -> $target. Incompatible addons can break startup, configs, or worlds."

  elo_ui_cache_reset || return
  plan="$ELO_UI_CACHE_DIR/migration-plan.tsv"
  errors="$ELO_UI_CACHE_DIR/migration-errors"
  status="$ELO_UI_CACHE_DIR/migration-status"
  if ! elo_ui_run_with_spinner "Analyzing addon compatibility..." "$plan" "$errors" "$status" \
    elo_migration_plan_create "$instance" "$target"; then
    return 1
  fi
  elo_ui_migration_report "$instance" "$current" "$target" "$plan" || return 0

  choice="$(elo_ui_choose_header "Version change action" \
    "Migrate compatible addons; keep incompatible" \
    "Migrate compatible addons; choose incompatible removals" \
    "Change version only; keep every addon unchanged" "Cancel")" || return 0
  case "$choice" in
    "Change version only; keep every addon unchanged")
      elo_ui_confirm "Change to $target without migrating addons?" || return 0
      elo_kv_set "$(elo_instance_dir "$instance")/instance.conf" MINECRAFT_VERSION "$target"
      elo_warn "Version changed; addon files remain unchanged."
      ;;
    "Migrate compatible addons; choose incompatible removals")
      remove_keys="$(elo_ui_migration_select_removals "$plan")"
      if [[ -n "$remove_keys" ]]; then
        count="$(printf '%s' "$remove_keys" | awk -F, '{ print NF }')"
      fi
      elo_ui_confirm "Migrate compatible addons, remove $count selected incompatible addons, and change to $target?" || return 0
      elo_migration_apply "$instance" "$target" "$plan" "$remove_keys"
      ;;
    "Migrate compatible addons; keep incompatible")
      elo_ui_confirm "Migrate compatible addons, keep incompatible addons, and change to $target?" || return 0
      elo_migration_apply "$instance" "$target" "$plan" ""
      ;;
  esac
}

elo_ui_import_mrpack() {
  local source pack addon provider name
  source="$(elo_ui_choose_header "Import source" "Provider project" "Local .mrpack file")" || return 0
  if [[ "$source" == "Local .mrpack file" ]]; then
    pack="$(elo_ui_file "Select a Modrinth .mrpack file" "$HOME")" || return 0
    [[ -n "$pack" ]] || return 0
    name="$(elo_ui_input "New instance name" "fabric-modpack")" || return 0
    [[ -n "$name" ]] || return 0
    elo_cmd_import_mrpack "$name" "$pack"
  else
    addon="$(elo_ui_input "Modpack ID or slug" "fabulously-optimized")" || return 0
    [[ -n "$addon" ]] || return 0
    provider="$(elo_ui_select_provider "Import provider")" || return 0
    name="$(elo_ui_input "New instance name" "fabric-modpack")" || return 0
    [[ -n "$name" ]] || return 0
    if [[ -n "$provider" ]]; then
      elo_cmd_import "$name" "$addon" --provider "$provider"
    else
      elo_cmd_import "$name" "$addon"
    fi
  fi
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
    1 "tsv" elo_ui_search_page_loader "$provider" "$query" "$type" "$instance"
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
    project_type="modpack"
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
  if [[ "$project_type" == "modpack" ]] && declare -F elo_mrpack_instance_is_empty >/dev/null 2>&1 &&
    ! elo_mrpack_instance_is_empty "$instance"; then
    "$ELO_GUM_COMMAND" style --foreground "$ELO_UI_ALERT" \
      "Instance '$instance' is not empty. Installing into a new/empty instance is recommended to avoid conflicts."
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

elo_ui_select_release_version() {
  local repository="$1" snapshot errors status_file tag published prerelease selection
  local -a options
  elo_ui_cache_reset || return
  snapshot="$ELO_UI_CACHE_DIR/releases"
  errors="$ELO_UI_CACHE_DIR/errors"
  status_file="$ELO_UI_CACHE_DIR/status"
  elo_ui_run_with_spinner "Fetching releases from $repository..." "$snapshot" "$errors" "$status_file" \
    elo_update_list_releases "$repository" || return 1
  [[ -s "$snapshot" ]] || {
    elo_warn "No releases found for $repository."
    return 1
  }
  options=()
  while IFS=$'\t' read -r tag published prerelease; do
    [[ -n "$tag" ]] || continue
    options+=("$tag ($published, $prerelease)")
  done <"$snapshot"
  selection="$(elo_ui_choose_header "Select a release" "${options[@]}")" || return 1
  printf '%s\n' "${selection%% (*}"
}

elo_ui_update() {
  local mode version updated=1
  mode="$(elo_ui_choose_header "Elo release" \
    "Latest stable release" "Specific version" "Browse releases" "Back")" || return 0
  case "$mode" in
    "Latest stable release") elo_cmd_update && updated=0 ;;
    "Specific version")
      version="$(elo_ui_input "Release version" "v0.4.0")" || return 0
      [[ -n "$version" ]] && elo_cmd_update --version "$version" && updated=0
      ;;
    "Browse releases")
      version="$(elo_ui_select_release_version "$(elo_repository)")" || return 0
      [[ -n "$version" ]] && elo_cmd_update --version "$version" && updated=0
      ;;
  esac
  if ((updated == 0)) && declare -F elo_self_restart >/dev/null 2>&1; then
    elo_self_restart
  fi
  return 0
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
    "Create instance" "Import modpack" "Change instance version" \
    "Activate instance" "Reset managed links" "List instances" \
    "Remove instance" "Back")" || return 0
  case "$action" in
    "Create instance") elo_ui_new ;;
    "Import modpack") elo_ui_import_mrpack ;;
    "Change instance version") elo_ui_change_version ;;
    "Activate instance") elo_ui_activate ;;
    "Reset managed links") elo_cmd_reset ;;
    "List instances") elo_ui_paginated_command "Instances" 1 "24,12,12,0" elo_cmd_list ;;
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
  elo_check_for_updates || true
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
