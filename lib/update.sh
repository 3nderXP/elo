#!/usr/bin/env bash

elo_update_read_config() {
  local config="$1"
  local wanted="$2"
  local key value

  [[ -f "$config" ]] || return 1
  while IFS='=' read -r key value; do
    if [[ "$key" == "$wanted" ]]; then
      printf '%s\n' "$value"
      return
    fi
  done <"$config"
  return 1
}

elo_update_install_root() {
  local releases

  releases="$(dirname -- "$ELO_SCRIPT_DIR")"
  [[ "$(basename -- "$releases")" == "releases" ]] || {
    elo_die "Update is available only from an installed Elo release."
    return 1
  }
  dirname -- "$releases"
}

elo_update_validate_version() {
  local version="$1"

  [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || {
    elo_die "Invalid release version: $version"
    return 1
  }
}

elo_update_latest_stable() {
  local repository="$1"
  local effective_url version

  effective_url="$(
    curl -fsSL -o /dev/null -w '%{url_effective}\n' \
      "https://github.com/$repository/releases/latest"
  )" || {
    elo_die "Failed to resolve the latest stable release."
    return 1
  }
  version="${effective_url##*/tag/}"
  [[ "$version" != "$effective_url" ]] || {
    elo_die "GitHub did not return a stable release."
    return 1
  }
  elo_update_validate_version "$version" || return
  printf '%s\n' "$version"
}

elo_update_normalize_version() {
  local version="$1"

  elo_update_validate_version "$version" || return
  case "$version" in
    v*) printf '%s\n' "$version" ;;
    *) printf 'v%s\n' "$version" ;;
  esac
}

elo_update_prune_releases() {
  local install_root="$1"
  local previous_release="$2"
  local releases active_release candidate resolved name

  releases="$install_root/releases"
  active_release="$(cd -- "$install_root/current" && pwd -P)" || {
    elo_warn "Could not identify the active release; old releases were not removed."
    return
  }

  case "$active_release:$previous_release" in
    "$releases"/*:"$releases"/*) ;;
    *)
      elo_warn "Release paths are outside the managed directory; old releases were not removed."
      return
      ;;
  esac

  for candidate in "$releases"/*; do
    [[ -d "$candidate" && ! -L "$candidate" ]] || continue
    resolved="$(cd -- "$candidate" && pwd -P)" || continue
    if [[ "$resolved" == "$active_release" || "$resolved" == "$previous_release" ]]; then
      continue
    fi

    name="$(basename -- "$candidate")"
    if [[ ! "$name" =~ ^[0-9]{14}-[0-9]+$ ||
      ! -f "$candidate/elo.sh" ||
      ! -d "$candidate/lib" ]]; then
      elo_warn "Unknown entry preserved in releases directory: $candidate"
      continue
    fi

    if ! rm -rf -- "$candidate"; then
      elo_warn "Could not remove old release: $candidate"
    fi
  done
}

elo_cmd_update() {
  local requested="" assume_yes=0
  local install_root config repository bin_dir version stage installer
  local previous_release=""

  while (($# > 0)); do
    case "$1" in
      --version)
        elo_require_value "$1" "${2:-}" || return
        requested="$2"
        shift 2
        ;;
      --yes)
        assume_yes=1
        shift
        ;;
      *)
        elo_die "Unknown option: $1"
        return
        ;;
    esac
  done

  command -v curl >/dev/null 2>&1 || {
    elo_die "curl is required for updates."
    return 1
  }

  install_root="$(elo_update_install_root)" || return
  config="$install_root/install.conf"
  repository="$(
    elo_update_read_config "$config" REPOSITORY ||
      printf '%s\n' "${ELO_REPOSITORY:-3nderXP/elo}"
  )"
  bin_dir="$(
    elo_update_read_config "$config" BIN_DIR ||
      printf '%s\n' "${ELO_BIN_DIR:-$HOME/.local/bin}"
  )"

  if [[ -n "$requested" ]]; then
    version="$(elo_update_normalize_version "$requested")" || return
  else
    version="$(elo_update_latest_stable "$repository")" || return
  fi

  if ((assume_yes == 0)); then
    elo_confirm "Install and activate Elo $version?" || return
  fi

  if [[ -d "$install_root/current" ]]; then
    previous_release="$(cd -- "$install_root/current" && pwd -P)" ||
      previous_release=""
  fi

  stage="$(mktemp -d "${TMPDIR:-/tmp}/elo-update.XXXXXX")"
  installer="$stage/install.sh"
  if ! curl -fsSL \
    "https://raw.githubusercontent.com/$repository/$version/install.sh" \
    -o "$installer"; then
    rm -rf -- "$stage"
    elo_die "Release not found or installer download failed: $version"
    return 1
  fi

  if ! bash "$installer" \
    --repo "$repository" \
    --ref "$version" \
    --install-dir "$install_root" \
    --bin-dir "$bin_dir"; then
    rm -rf -- "$stage"
    elo_die "Update failed; the previous release remains active."
    return 1
  fi
  rm -rf -- "$stage"
  if [[ -n "$previous_release" ]]; then
    elo_update_prune_releases "$install_root" "$previous_release"
  else
    elo_warn "Could not identify the previous release; old releases were not removed."
  fi
  elo_info "Elo updated to $version."
}
