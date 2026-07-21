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
  elo_install_dir || {
    elo_die "Update is available only from an installed Elo release."
    return 1
  }
}

elo_update_is_semver() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]
}

elo_update_validate_version() {
  local version="$1"

  elo_update_is_semver "$version" || {
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

elo_self_restart() {
  declare -F elo_ui_cleanup >/dev/null 2>&1 && elo_ui_cleanup
  elo_info "Restarting Elo to load the updated version..."
  exec "${ELO_ORIGINAL_ARGV0:-$0}"
}

elo_cmd_version() {
  (($# == 0)) || {
    elo_die "Usage: elo version"
    return
  }
  printf 'Elo %s\n' "$(elo_get_current_version)"
}

elo_get_current_version() {
  local install_root version
  install_root="$(elo_install_dir)" || {
    printf 'unknown\n'
    return 0
  }
  version="$(elo_update_read_config "$install_root/install.conf" CURRENT_VERSION || true)"
  printf '%s\n' "${version:-unknown}"
}

elo_version_gt() {
  local a="${1#v}" b="${2#v}"
  [[ "$a" != "$b" ]] || return 1
  [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" ]]
}

elo_check_for_updates() {
  local install_root notice_file current_version latest_version
  local last_check_time now cache_age=86400

  unset ELO_LATEST_VERSION ELO_UPDATE_AVAILABLE
  install_root="$(elo_install_dir)" || return 0
  notice_file="$install_root/update_notice.conf"
  now="$(date +%s)"

  last_check_time="$(elo_update_read_config "$notice_file" LAST_CHECK_TIME || true)"
  if [[ "$last_check_time" =~ ^[0-9]+$ ]] && ((now - last_check_time < cache_age)); then
    ELO_LATEST_VERSION="$(elo_update_read_config "$notice_file" LATEST_VERSION || true)"
  else
    latest_version="$(elo_update_latest_stable "$(elo_repository)" || true)"
    [[ -n "$latest_version" ]] || return 0
    ELO_LATEST_VERSION="$latest_version"
    elo_kv_set "$notice_file" LATEST_VERSION "$latest_version"
    elo_kv_set "$notice_file" LAST_CHECK_TIME "$now"
  fi

  current_version="$(elo_get_current_version)"
  if [[ -n "$ELO_LATEST_VERSION" && "$current_version" != "unknown" ]] &&
    elo_version_gt "$ELO_LATEST_VERSION" "$current_version"; then
    ELO_UPDATE_AVAILABLE=1
  fi
}

elo_update_list_releases() {
  local repository="$1"

  command -v jq >/dev/null 2>&1 || {
    elo_die "jq is required to list releases."
    return 1
  }
  curl -fsSL "https://api.github.com/repos/$repository/releases?per_page=30" | jq -r '
    .[] | select(.draft == false) |
    [.tag_name, (.published_at // "" | .[:10]), (if .prerelease then "pre-release" else "stable" end)] |
    @tsv' || {
    elo_die "Failed to list releases for $repository."
    return 1
  }
}
