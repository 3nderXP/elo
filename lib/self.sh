#!/usr/bin/env bash

elo_self_install_root() {
  local releases root active

  releases="$(dirname -- "$ELO_SCRIPT_DIR")"
  [[ "$(basename -- "$releases")" == "releases" ]] || {
    elo_die "Uninstall is available only from an installed Elo release."
    return 1
  }
  root="$(dirname -- "$releases")"
  [[ -f "$root/install.conf" && -L "$root/current" ]] || {
    elo_die "The Elo installation layout is incomplete; nothing was removed."
    return 1
  }
  active="$(cd -- "$root/current" && pwd -P)" || return
  [[ "$active" == "$ELO_SCRIPT_DIR" ]] || {
    elo_die "The running Elo release is not the active installed release."
    return 1
  }
  printf '%s\n' "$root"
}

elo_self_config_get() {
  local file="$1" wanted="$2" key value

  while IFS='=' read -r key value; do
    if [[ "$key" == "$wanted" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done <"$file"
  return 1
}

elo_cmd_uninstall() {
  local purge=0 purge_data=0 root config bin_dir command_path legacy_gum legacy_target preserved_gum
  local shortcut_path shortcut_directory warp_config_path

  while (($# > 0)); do
    case "$1" in
      --purge) purge=1; shift ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Usage: elo uninstall [--purge] [--yes]"; return ;;
    esac
  done

  root="$(elo_self_install_root)" || return
  config="$root/install.conf"
  bin_dir="$(elo_self_config_get "$config" BIN_DIR)" || {
    elo_die "The installation manifest does not define BIN_DIR."
    return 1
  }
  command_path="$bin_dir/elo"
  [[ -L "$command_path" && "$(readlink "$command_path")" == "$root/current/elo.sh" ]] || {
    elo_die "The Elo command is not an installer-owned symlink; nothing was removed."
    return 1
  }
  shortcut_path="$(elo_self_config_get "$config" SHORTCUT_PATH || true)"
  warp_config_path="$(elo_self_config_get "$config" WARP_CONFIG_PATH || true)"

  if ((purge == 1)); then
    if [[ -f "$ELO_CONFIG_FILE" && -d "$ELO_INSTANCES_DIR" ]]; then
      [[ "$ELO_HOME" != "/" && "$ELO_HOME" != "$HOME" && -n "$ELO_HOME" ]] || {
        elo_die "Refusing to purge an unsafe ELO_HOME path."
        return 1
      }
      purge_data=1
    else
      elo_warn "No initialized Elo data was found at $ELO_HOME; that path will be preserved."
    fi
    if ((purge_data == 1)); then
      elo_confirm "Uninstall Elo and permanently delete all data in '$ELO_HOME'?" || {
        elo_warn "Uninstall cancelled."
        return 1
      }
    else
      elo_confirm "Uninstall Elo?" || {
        elo_warn "Uninstall cancelled."
        return 1
      }
    fi
  else
    case "$ELO_HOME" in
      "$root" | "$root"/*)
        elo_die "ELO_HOME is inside the installation root and cannot be preserved."
        return 1
        ;;
    esac
    elo_confirm "Uninstall Elo and preserve instance data in '$ELO_HOME'?" || {
      elo_warn "Uninstall cancelled."
      return 1
    }
  fi

  if [[ -f "$ELO_CONFIG_FILE" ]]; then
    elo_cmd_reset || return
  fi

  legacy_gum="$bin_dir/gum"
  if [[ -L "$legacy_gum" ]]; then
    legacy_target="$(readlink "$legacy_gum")"
    case "$legacy_target" in
      "$root"/tools/gum-*/gum)
        if [[ -f "$legacy_target" && ! -L "$legacy_target" ]]; then
          preserved_gum="$(mktemp "$bin_dir/.elo-gum-preserved.XXXXXX")"
          cp "$legacy_target" "$preserved_gum"
          chmod +x "$preserved_gum"
          rm -- "$legacy_gum"
          mv -- "$preserved_gum" "$legacy_gum"
          elo_warn "Preserved the legacy global Gum command for other consumers."
        fi
        ;;
    esac
  fi

  if [[ -n "$shortcut_path" && -f "$shortcut_path" ]] &&
    grep -Fx 'X-Elo-Managed=true' "$shortcut_path" >/dev/null 2>&1; then
    shortcut_directory="$(dirname "$shortcut_path")"
    rm -- "$shortcut_path"
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "$shortcut_directory" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$warp_config_path" && -f "$warp_config_path" ]] &&
    grep -Fx '# Managed by the Elo installer.' "$warp_config_path" >/dev/null 2>&1; then
    rm -- "$warp_config_path"
  fi
  rm -- "$command_path"
  rm -rf -- "$root"
  if ((purge_data == 1)); then
    rm -rf -- "$ELO_HOME"
    elo_info "Elo and its data were uninstalled."
  else
    elo_info "Elo was uninstalled. Instance data was preserved at $ELO_HOME"
  fi
}
