#!/usr/bin/env bash

elo_info() {
  printf 'info: %s\n' "$*"
}

elo_progress() {
  local label="$1" current="$2" total="$3" width=42 filled empty percent bar
  (( total > 0 )) || return 0
  percent=$((current * 100 / total)); filled=$((current * width / total)); empty=$((width - filled))
  if [[ -t 1 ]]; then
    bar="$(printf '%*s' "$filled" '' | tr ' ' '█')$(printf '%*s' "$empty" '' | tr ' ' '▒')"
    printf '\r\033[2K%s [%s] %3d%% (%d/%d) %s' "$label" "$bar" "$percent" "$current" "$total" "${4:-}"
    (( current == total )) && printf '\n'
  else
    elo_info "$label progress: $current/$total ($percent%): ${4:-}"
  fi
}

elo_warn() {
  printf 'warning: %s\n' "$*" >&2
}

elo_error() {
  printf 'error: %s\n' "$*" >&2
}

elo_die() {
  elo_error "$*"
  return 1
}

elo_gum_command() {
  local releases root config key value candidate gum_path
  releases="$(dirname -- "${ELO_SCRIPT_DIR:-.}")"
  if [[ "$(basename -- "$releases")" == "releases" ]]; then
    root="$(dirname -- "$releases")"
    config="$root/install.conf"
    if [[ -f "$config" ]]; then
      while IFS='=' read -r key value; do
        [[ "$key" == "GUM_PATH" ]] || continue
        case "$value" in
          "$root"/tools/gum-*/gum)
            if [[ -x "$value" && ! -L "$value" ]]; then
              printf '%s\n' "$value"
              return 0
            fi
            ;;
        esac
      done <"$config"
    fi
    for candidate in "$root"/tools/gum-*/gum; do
      if [[ -x "$candidate" && ! -L "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  fi
  gum_path="$(command -v gum || true)"
  [[ -n "$gum_path" ]] || return 1
  printf '%s\n' "$gum_path"
}

elo_confirm() {
  local prompt="$1"
  local answer gum_command

  if [[ "${ELO_ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    elo_die "$prompt Use --yes for non-interactive execution."
    return 1
  fi

  gum_command="$(elo_gum_command || true)"
  if [[ -n "$gum_command" ]]; then
    "$gum_command" confirm --prompt.foreground 212 --selected.background 212 "$prompt"
    return
  fi

  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

elo_validate_instance_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    elo_die "Invalid instance name: use only letters, numbers, '_' and '-'."
    return 1
  fi
}

elo_validate_managed_folder() {
  local folder="$1"
  elo_validate_managed_path "$folder" || {
    elo_die "Invalid name in MANAGED_FOLDERS: $folder"
    return 1
  }
}

elo_validate_managed_path() {
  local path="$1" part
  [[ -n "$path" && "$path" != /* && "$path" != */ && "$path" != *//* && \
    "$path" != *$'\n'* && "$path" != *$'\r'* && "$path" != *$'\t'* && \
    "$path" != *\\* && "$path" != *'='* && ! "$path" =~ ^[a-zA-Z]: ]] || return 1
  while IFS= read -r part || [[ -n "$part" ]]; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
  done < <(printf '%s' "$path" | tr '/' '\n')
}

elo_require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    elo_die "Option $option requires a value."
    return 1
  fi
}

elo_absolute_existing_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    elo_die "Directory not found: $path"
    return 1
  fi
  (cd -- "$path" && pwd -P)
}
