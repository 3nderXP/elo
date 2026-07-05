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
    elo_die "Estado inconsistente: $destination deveria ser um symlink do Elo."
    return 1
  fi

  actual="$(elo_read_link "$destination")"
  if [[ "$actual" != "$expected" ]]; then
    elo_die "Recusando remover symlink não reconhecido: $destination -> $actual"
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
        elo_die "Backup original ausente: $backup"
        return 1
      fi
      if [[ -e "$destination" || -L "$destination" ]]; then
        elo_die "Não é seguro restaurar: o destino já existe em $destination"
        return 1
      fi
      mv -- "$backup" "$destination"
      ;;
    absent | removed)
      if [[ -e "$destination" || -L "$destination" ]]; then
        elo_die "Estado inconsistente: $destination deveria estar ausente."
        return 1
      fi
      ;;
    *)
      elo_die "Estado original desconhecido para '$folder': $original"
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
    elo_die "Já existe um symlink não gerenciado pelo Elo em $destination."
    return 1
  fi

  if [[ -e "$destination" ]]; then
    if [[ -n "$original" ]]; then
      elo_die "Estado inconsistente para $destination (ORIGINAL_$folder=$original)."
      return 1
    fi

    if [[ "$mode" == "backup" ]]; then
      if [[ -e "$backup" || -L "$backup" ]]; then
        elo_die "Backup já existe e não será sobrescrito: $backup"
        return 1
      fi
      mkdir -p -- "$ELO_BACKUP_DIR"
      mv -- "$destination" "$backup"
      elo_state_set "$(elo_original_key "$folder")" backed_up
    else
      elo_confirm "O modo replace removerá permanentemente '$destination'. Continuar?" || {
        elo_warn "Operação cancelada."
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
        elo_die "Estado inconsistente: $destination não é mais um symlink."
        return
      fi
      actual="$(elo_read_link "$destination")"
      if [[ "$actual" != "$expected" ]]; then
        elo_die "Symlink alterado externamente: $destination -> $actual"
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
  elo_info "Instância ativa: $name"
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
        elo_die "Opção inválida: $1"
        return
        ;;
    esac
  done

  if [[ "$ELO_PARSED_MODE" != "backup" && "$ELO_PARSED_MODE" != "replace" ]]; then
    elo_die "Modo inválido: use backup ou replace."
    return 1
  fi
}

elo_cmd_link() {
  local name="${1:-}" mode="backup" active

  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Uso: elo link <nome-instancia> [--mode backup|replace] [--yes]"
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
    elo_confirm "Deseja trocar a instância ativa de '$active' para '$name'?" || {
      elo_warn "Troca cancelada."
      return 1
    }
  elif [[ "$mode" == "replace" ]]; then
    elo_confirm "Tem certeza de que deseja ativar '$name' no modo replace? Pastas reais poderão ser removidas permanentemente." || {
      elo_warn "Ativação cancelada."
      return 1
    }
  else
    elo_confirm "Deseja ativar a instância '$name'? Pastas reais serão preservadas em backup." || {
      elo_warn "Ativação cancelada."
      return 1
    }
  fi

  elo_activate_instance "$name" "$mode"
}

elo_cmd_switch() {
  local name="${1:-}"
  local active

  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Uso: elo switch <nome-instancia> [--yes]"
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
        elo_die "Opção inválida para switch: $1"
        return
        ;;
    esac
  done

  elo_require_initialized || return
  elo_require_instance "$name" || return
  active="$(elo_active_instance)"

  if [[ "$active" == "$name" ]]; then
    elo_info "A instância '$name' já está ativa."
    return
  fi

  if [[ -n "$active" ]]; then
    elo_confirm "Deseja trocar a instância ativa de '$active' para '$name'?" || {
      elo_warn "Troca cancelada."
      return 1
    }
  else
    elo_confirm "Nenhuma instância está ativa. Deseja ativar '$name'?" || {
      elo_warn "Ativação cancelada."
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
        elo_die "Opção inválida para reset: $1"
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
    elo_info "Nada para resetar; o Elo não está gerenciando nenhuma instância."
    return
  fi

  elo_confirm "Deseja desfazer o gerenciamento e restaurar as pastas originais?" || {
    elo_warn "Reset cancelado."
    return 1
  }

  for folder in $folders; do
    elo_validate_managed_folder "$folder" || return
    if ! elo_release_folder "$folder" "$minecraft_path"; then
      failed=1
    fi
  done

  if ((failed != 0)); then
    elo_die "Reset incompleto. Os dados preservados não foram descartados."
    return 1
  fi

  elo_config_set ACTIVE_INSTANCE ""
  elo_info "Gerenciamento desfeito; pastas originais restauradas."
}

elo_cmd_status() {
  local minecraft_path active folders folder linked original destination expected actual state
  local inconsistent=0

  elo_require_initialized || return
  minecraft_path="$(elo_minecraft_path)" || return
  active="$(elo_active_instance)"
  folders="$(elo_managed_folders)"

  printf 'Minecraft: %s\n' "$minecraft_path"
  printf 'Instância ativa: %s\n' "${active:--}"
  printf '%-16s %-20s %-12s %s\n' "PASTA" "LINK" "ORIGINAL" "ESTADO"

  for folder in $folders; do
    elo_validate_managed_folder "$folder" || return
    linked="$(elo_state_get "$(elo_linked_key "$folder")" || true)"
    original="$(elo_state_get "$(elo_original_key "$folder")" || true)"
    destination="$minecraft_path/$folder"
    state="não gerenciada"

    if [[ -n "$linked" ]]; then
      expected="$(elo_expected_link_target "$linked" "$folder")"
      if [[ -L "$destination" ]]; then
        actual="$(elo_read_link "$destination")"
        if [[ "$actual" == "$expected" && -e "$destination" ]]; then
          state="ok"
        elif [[ "$actual" == "$expected" ]]; then
          state="link quebrado"
          inconsistent=1
        else
          state="link divergente"
          inconsistent=1
        fi
      else
        state="link ausente"
        inconsistent=1
      fi
      if [[ -n "$active" && "$linked" != "$active" ]]; then
        state="instância divergente"
        inconsistent=1
      fi
    elif [[ -L "$destination" ]]; then
      state="symlink externo"
    elif [[ -e "$destination" ]]; then
      state="pasta real"
    fi

    printf '%-16s %-20s %-12s %s\n' "$folder" "${linked:--}" "${original:--}" "$state"
  done

  ((inconsistent == 0))
}
