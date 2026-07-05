#!/usr/bin/env bash

ELO_HOME="${ELO_HOME:-$HOME/.elo}"
if [[ "$ELO_HOME" != /* ]]; then
  ELO_HOME="$PWD/$ELO_HOME"
fi
ELO_CONFIG_FILE="$ELO_HOME/config.conf"
ELO_STATE_FILE="$ELO_HOME/state.conf"
ELO_INSTANCES_DIR="$ELO_HOME/instances"
ELO_BACKUP_DIR="$ELO_HOME/backups/original"
ELO_DEFAULT_MANAGED_FOLDERS="mods resourcepacks shaderpacks config"

elo_kv_get() {
  local file="$1"
  local key="$2"
  local line value

  [[ -f "$file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$key="* ]] || continue
    value="${line#*=}"
    if [[ ${#value} -ge 2 && "$value" == \"*\" ]]; then
      value="${value:1:${#value}-2}"
    fi
    printf '%s\n' "$value"
    return 0
  done <"$file"

  return 1
}

elo_kv_set() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temp line found=0

  if [[ "$value" == *$'\n'* ]]; then
    elo_die "Configuration values cannot contain newlines."
    return 1
  fi

  mkdir -p -- "$(dirname -- "$file")"
  temp="$(mktemp "${file}.tmp.XXXXXX")"

  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$key="* ]]; then
        printf '%s=%s\n' "$key" "$value" >>"$temp"
        found=1
      else
        printf '%s\n' "$line" >>"$temp"
      fi
    done <"$file"
  fi

  if ((found == 0)); then
    printf '%s=%s\n' "$key" "$value" >>"$temp"
  fi

  mv -- "$temp" "$file"
}

elo_kv_unset() {
  local file="$1"
  local key="$2"
  local temp line

  [[ -f "$file" ]] || return 0
  temp="$(mktemp "${file}.tmp.XXXXXX")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$key="* ]] && continue
    printf '%s\n' "$line" >>"$temp"
  done <"$file"

  mv -- "$temp" "$file"
}

elo_config_get() {
  elo_kv_get "$ELO_CONFIG_FILE" "$1"
}

elo_config_set() {
  elo_kv_set "$ELO_CONFIG_FILE" "$1" "$2"
}

elo_state_get() {
  elo_kv_get "$ELO_STATE_FILE" "$1"
}

elo_state_set() {
  elo_kv_set "$ELO_STATE_FILE" "$1" "$2"
}

elo_state_unset() {
  elo_kv_unset "$ELO_STATE_FILE" "$1"
}

elo_require_initialized() {
  if [[ ! -f "$ELO_CONFIG_FILE" ]]; then
    elo_die "Elo is not initialized. Run 'elo init --minecraft-path <path>'."
    return 1
  fi
}

elo_minecraft_path() {
  local path
  path="$(elo_config_get MINECRAFT_PATH || true)"
  if [[ -z "$path" ]]; then
    elo_die "MINECRAFT_PATH is not defined in $ELO_CONFIG_FILE."
    return 1
  fi
  printf '%s\n' "$path"
}

elo_managed_folders() {
  local folders
  folders="$(elo_config_get MANAGED_FOLDERS || true)"
  printf '%s\n' "${folders:-$ELO_DEFAULT_MANAGED_FOLDERS}"
}

elo_active_instance() {
  elo_config_get ACTIVE_INSTANCE || true
}

elo_cmd_init() {
  local minecraft_path=""

  while (($# > 0)); do
    case "$1" in
      --minecraft-path)
        elo_require_value "$1" "${2:-}" || return
        minecraft_path="$2"
        shift 2
        ;;
      *)
        elo_die "Invalid option for init: $1"
        return
        ;;
    esac
  done

  if [[ -z "$minecraft_path" ]]; then
    elo_die "Provide --minecraft-path <path>."
    return
  fi
  minecraft_path="$(elo_absolute_existing_dir "$minecraft_path")" || return

  if [[ -f "$ELO_CONFIG_FILE" ]]; then
    elo_die "Elo is already initialized in $ELO_HOME."
    return
  fi

  mkdir -p -- "$ELO_INSTANCES_DIR" "$ELO_BACKUP_DIR"
  : >"$ELO_CONFIG_FILE"
  : >"$ELO_STATE_FILE"
  elo_config_set MINECRAFT_PATH "$minecraft_path"
  elo_config_set ACTIVE_INSTANCE ""
  elo_config_set MANAGED_FOLDERS "$ELO_DEFAULT_MANAGED_FOLDERS"
  elo_info "Elo initialized. .minecraft: $minecraft_path"
}
