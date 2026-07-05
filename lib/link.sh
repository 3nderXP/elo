#!/usr/bin/env bash

elo_linked_key() {
  printf 'LINKED_%s\n' "$1"
}

elo_original_key() {
  printf 'ORIGINAL_%s\n' "$1"
}

elo_expected_link_target() {
  local instance="$1"
  local folder="$2"
  printf '%s/%s/%s\n' "$ELO_INSTANCES_DIR" "$instance" "$folder"
}

elo_read_link() {
  readlink "$1"
}

elo_remove_managed_link() {
  local folder="$1"
  local minecraft_path="$2"
  local linked destination expected actual

  linked="$(elo_state_get "$(elo_linked_key "$folder")" || true)"
  [[ -n "$linked" ]] || return 0

  destination="$minecraft_path/$folder"
  expected="$(elo_expected_link_target "$linked" "$folder")"

  if [[ ! -L "$destination" ]]; then
    elo_die "Inconsistent state: $destination should be an Elo symlink."
    return 1
  fi

  actual="$(elo_read_link "$destination")"
  if [[ "$actual" != "$expected" ]]; then
    elo_die "Refusing to remove unrecognized symlink: $destination -> $actual"
    return 1
  fi

  rm -- "$destination"
  elo_state_unset "$(elo_linked_key "$folder")"
}

elo_restore_original() {
  local folder="$1"
  local minecraft_path="$2"
  local original destination backup

  original="$(elo_state_get "$(elo_original_key "$folder")" || true)"
  [[ -n "$original" ]] || return 0

  destination="$minecraft_path/$folder"
  backup="$ELO_BACKUP_DIR/$folder.bak"

  case "$original" in
    backed_up)
      if [[ ! -e "$backup" && ! -L "$backup" ]]; then
        elo_die "Original backup is missing: $backup"
        return 1
      fi
      if [[ -e "$destination" || -L "$destination" ]]; then
        elo_die "Cannot restore safely: destination already exists at $destination"
        return 1
      fi
      mv -- "$backup" "$destination"
      ;;
    absent | removed)
      if [[ -e "$destination" || -L "$destination" ]]; then
        elo_die "Inconsistent state: $destination should be absent."
        return 1
      fi
      ;;
    *)
      elo_die "Unknown original state for '$folder': $original"
      return 1
      ;;
  esac

  elo_state_unset "$(elo_original_key "$folder")"
}

elo_release_folder() {
  local folder="$1"
  local minecraft_path="$2"
  elo_remove_managed_link "$folder" "$minecraft_path" || return
  elo_restore_original "$folder" "$minecraft_path"
}

elo_prepare_destination() {
  local folder="$1"
  local minecraft_path="$2"
  local mode="$3"
  local destination backup original

  destination="$minecraft_path/$folder"
  backup="$ELO_BACKUP_DIR/$folder.bak"
  original="$(elo_state_get "$(elo_original_key "$folder")" || true)"

  if [[ -L "$destination" ]]; then
    elo_die "An unmanaged symlink already exists at $destination."
    return 1
  fi

  if [[ -e "$destination" ]]; then
    if [[ -n "$original" ]]; then
      elo_die "Inconsistent state for $destination (ORIGINAL_$folder=$original)."
      return 1
    fi

    if [[ "$mode" == "backup" ]]; then
      if [[ -e "$backup" || -L "$backup" ]]; then
        elo_die "Backup already exists and will not be overwritten: $backup"
        return 1
      fi
      mkdir -p -- "$ELO_BACKUP_DIR"
      mv -- "$destination" "$backup"
      elo_state_set "$(elo_original_key "$folder")" backed_up
    else
      elo_confirm "Replace mode will permanently remove '$destination'. Continue?" || {
        elo_warn "Operation cancelled."
        return 1
      }
      rm -rf -- "$destination"
      elo_state_set "$(elo_original_key "$folder")" removed
    fi
  elif [[ -z "$original" ]]; then
    elo_state_set "$(elo_original_key "$folder")" absent
  fi
}

elo_activate_instance() {
  local name="$1"
  local mode="$2"
  local minecraft_path instance_dir folders folder source destination linked expected actual

  elo_require_initialized || return
  elo_require_instance "$name" || return
  minecraft_path="$(elo_minecraft_path)" || return
  instance_dir="$(elo_instance_dir "$name")"
  folders="$(elo_managed_folders)"

  for folder in $folders; do
    elo_validate_managed_folder "$folder" || return
    source="$instance_dir/$folder"
    destination="$minecraft_path/$folder"
    linked="$(elo_state_get "$(elo_linked_key "$folder")" || true)"

    if [[ ! -d "$source" ]]; then
      if [[ -n "$linked" ]]; then
        elo_release_folder "$folder" "$minecraft_path" || return
      fi
      continue
    fi

    if [[ -n "$linked" ]]; then
      expected="$(elo_expected_link_target "$linked" "$folder")"
      if [[ ! -L "$destination" ]]; then
        elo_die "Inconsistent state: $destination is no longer a symlink."
        return
      fi
      actual="$(elo_read_link "$destination")"
      if [[ "$actual" != "$expected" ]]; then
        elo_die "Symlink was changed externally: $destination -> $actual"
        return
      fi
      if [[ "$linked" == "$name" ]]; then
        continue
      fi
      elo_remove_managed_link "$folder" "$minecraft_path" || return
    fi

    elo_prepare_destination "$folder" "$minecraft_path" "$mode" || return
    ln -s -- "$source" "$destination"
    elo_state_set "$(elo_linked_key "$folder")" "$name"
  done

  elo_config_set ACTIVE_INSTANCE "$name"
  elo_info "Active instance: $name"
}

elo_parse_activation_options() {
  ELO_PARSED_MODE="backup"

  while (($# > 0)); do
    case "$1" in
      --mode)
        elo_require_value "$1" "${2:-}" || return
        ELO_PARSED_MODE="$2"
        shift 2
        ;;
      --mode=*)
        ELO_PARSED_MODE="${1#*=}"
        shift
        ;;
      --yes)
        ELO_ASSUME_YES=1
        shift
        ;;
      *)
        elo_die "Invalid option: $1"
        return
        ;;
    esac
  done

  if [[ "$ELO_PARSED_MODE" != "backup" && "$ELO_PARSED_MODE" != "replace" ]]; then
    elo_die "Invalid mode: use backup or replace."
    return 1
  fi
}

elo_cmd_link() {
  local name="${1:-}" mode="backup" active

  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Usage: elo link <instance-name> [--mode backup|replace] [--yes]"
    return
  fi
  shift
  elo_parse_activation_options "$@" || return
  mode="$ELO_PARSED_MODE"

  elo_require_initialized || return
  elo_require_instance "$name" || return
  active="$(elo_active_instance)"
  if [[ "$active" == "$name" ]]; then
    elo_activate_instance "$name" "$mode"
    return
  fi

  if [[ -n "$active" ]]; then
    elo_confirm "Switch the active instance from '$active' to '$name'?" || {
      elo_warn "Switch cancelled."
      return 1
    }
  elif [[ "$mode" == "replace" ]]; then
    elo_confirm "Activate '$name' in replace mode? Real directories may be removed permanently." || {
      elo_warn "Activation cancelled."
      return 1
    }
  else
    elo_confirm "Activate instance '$name'? Real directories will be backed up." || {
      elo_warn "Activation cancelled."
      return 1
    }
  fi

  elo_activate_instance "$name" "$mode"
}

elo_cmd_switch() {
  local name="${1:-}"
  local active

  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Usage: elo switch <instance-name> [--yes]"
    return
  fi
  shift

  while (($# > 0)); do
    case "$1" in
      --yes)
        ELO_ASSUME_YES=1
        shift
        ;;
      *)
        elo_die "Invalid option for switch: $1"
        return
        ;;
    esac
  done

  elo_require_initialized || return
  elo_require_instance "$name" || return
  active="$(elo_active_instance)"

  if [[ "$active" == "$name" ]]; then
    elo_info "Instance '$name' is already active."
    return
  fi

  if [[ -n "$active" ]]; then
    elo_confirm "Switch the active instance from '$active' to '$name'?" || {
      elo_warn "Switch cancelled."
      return 1
    }
  else
    elo_confirm "No instance is active. Activate '$name'?" || {
      elo_warn "Activation cancelled."
      return 1
    }
  fi

  elo_activate_instance "$name" backup
}

elo_cmd_reset() {
  local minecraft_path folders folder active pending=0 failed=0

  elo_require_initialized || return
  minecraft_path="$(elo_minecraft_path)" || return
  folders="$(elo_managed_folders)"
  active="$(elo_active_instance)"

  while (($# > 0)); do
    case "$1" in
      --yes)
        ELO_ASSUME_YES=1
        shift
        ;;
      *)
        elo_die "Invalid option for reset: $1"
        return
        ;;
    esac
  done

  for folder in $folders; do
    if [[ -n "$(elo_state_get "$(elo_linked_key "$folder")" || true)" ||
      -n "$(elo_state_get "$(elo_original_key "$folder")" || true)" ]]; then
      pending=1
      break
    fi
  done

  if [[ -z "$active" && "$pending" == "0" ]]; then
    elo_info "Nothing to reset; Elo is not managing an instance."
    return
  fi

  elo_confirm "Stop managing this instance and restore the original directories?" || {
    elo_warn "Reset cancelled."
    return 1
  }

  for folder in $folders; do
    elo_validate_managed_folder "$folder" || return
    if ! elo_release_folder "$folder" "$minecraft_path"; then
      failed=1
    fi
  done

  if ((failed != 0)); then
    elo_die "Reset incomplete. Preserved data was not discarded."
    return 1
  fi

  elo_config_set ACTIVE_INSTANCE ""
  elo_info "Management disabled; original directories restored."
}

elo_cmd_status() {
  local minecraft_path active folders folder linked original destination expected actual state
  local inconsistent=0

  elo_require_initialized || return
  minecraft_path="$(elo_minecraft_path)" || return
  active="$(elo_active_instance)"
  folders="$(elo_managed_folders)"

  printf 'Minecraft: %s\n' "$minecraft_path"
  printf 'Active instance: %s\n' "${active:--}"
  printf '%-16s %-20s %-12s %s\n' "FOLDER" "LINK" "ORIGINAL" "STATE"

  for folder in $folders; do
    elo_validate_managed_folder "$folder" || return
    linked="$(elo_state_get "$(elo_linked_key "$folder")" || true)"
    original="$(elo_state_get "$(elo_original_key "$folder")" || true)"
    destination="$minecraft_path/$folder"
    state="unmanaged"

    if [[ -n "$linked" ]]; then
      expected="$(elo_expected_link_target "$linked" "$folder")"
      if [[ -L "$destination" ]]; then
        actual="$(elo_read_link "$destination")"
        if [[ "$actual" == "$expected" && -e "$destination" ]]; then
          state="ok"
        elif [[ "$actual" == "$expected" ]]; then
          state="broken link"
          inconsistent=1
        else
          state="divergent link"
          inconsistent=1
        fi
      else
        state="missing link"
        inconsistent=1
      fi
      if [[ -n "$active" && "$linked" != "$active" ]]; then
        state="instance mismatch"
        inconsistent=1
      fi
    elif [[ -L "$destination" ]]; then
      state="external symlink"
    elif [[ -e "$destination" ]]; then
      state="real directory"
    fi

    printf '%-16s %-20s %-12s %s\n' "$folder" "${linked:--}" "${original:--}" "$state"
  done

  ((inconsistent == 0))
}
