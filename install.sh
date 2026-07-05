#!/usr/bin/env bash

set -euo pipefail

ELO_REPOSITORY="${ELO_REPOSITORY:-3nderXP/elo}"
ELO_REF="${ELO_REF:-main}"
ELO_INSTALL_DIR="${ELO_INSTALL_DIR:-$HOME/.local/share/elo}"
ELO_BIN_DIR="${ELO_BIN_DIR:-$HOME/.local/bin}"
ELO_SOURCE_DIR=""
ELO_INSTALL_STAGE=""

ELO_INSTALL_FILES=(
  "elo.sh"
  "lib/utils.sh"
  "lib/help.sh"
  "lib/config.sh"
  "lib/instance.sh"
  "lib/link.sh"
)

install_info() {
  printf 'info: %s\n' "$*"
}

install_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

install_usage() {
  cat <<'EOF'
Elo installer

Remote usage:
  curl -fsSL https://raw.githubusercontent.com/3nderXP/elo/main/install.sh | bash

Local usage:
  ./install.sh --source <repository-directory>

Options:
  --source <directory>      Install from a local checkout
  --install-dir <directory> Directory that stores installed releases
  --bin-dir <directory>     Directory where the elo command is created
  --repo <owner/repo>       Repository used for downloads
  --ref <ref>               Branch, tag, or commit used for downloads
  --help                    Show this help

Equivalent environment variables:
  ELO_INSTALL_DIR, ELO_BIN_DIR, ELO_REPOSITORY e ELO_REF
EOF
}

install_cleanup() {
  if [[ -n "$ELO_INSTALL_STAGE" && -d "$ELO_INSTALL_STAGE" ]]; then
    rm -rf "$ELO_INSTALL_STAGE"
  fi
}

install_require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || install_die "Option $option requires a value."
}

install_parse_options() {
  while (($# > 0)); do
    case "$1" in
      --source)
        install_require_value "$1" "${2:-}"
        ELO_SOURCE_DIR="$2"
        shift 2
        ;;
      --install-dir)
        install_require_value "$1" "${2:-}"
        ELO_INSTALL_DIR="$2"
        shift 2
        ;;
      --bin-dir)
        install_require_value "$1" "${2:-}"
        ELO_BIN_DIR="$2"
        shift 2
        ;;
      --repo)
        install_require_value "$1" "${2:-}"
        ELO_REPOSITORY="$2"
        shift 2
        ;;
      --ref)
        install_require_value "$1" "${2:-}"
        ELO_REF="$2"
        shift 2
        ;;
      --help | -h)
        install_usage
        exit 0
        ;;
      *)
        install_die "Unknown option: $1"
        ;;
    esac
  done
}

install_copy_local_files() {
  local stage="$1"
  local source file

  [[ -d "$ELO_SOURCE_DIR" ]] ||
    install_die "Source directory not found: $ELO_SOURCE_DIR"
  source="$(cd "$ELO_SOURCE_DIR" && pwd -P)"

  for file in "${ELO_INSTALL_FILES[@]}"; do
    [[ -f "$source/$file" ]] ||
      install_die "Required file is missing: $source/$file"
    mkdir -p "$(dirname "$stage/$file")"
    cp "$source/$file" "$stage/$file"
  done
}

install_download_files() {
  local stage="$1"
  local base_url file

  command -v curl >/dev/null 2>&1 ||
    install_die "curl is required for remote installation."

  base_url="https://raw.githubusercontent.com/$ELO_REPOSITORY/$ELO_REF"
  install_info "Downloading $ELO_REPOSITORY@$ELO_REF..."

  for file in "${ELO_INSTALL_FILES[@]}"; do
    mkdir -p "$(dirname "$stage/$file")"
    curl -fsSL "$base_url/$file" -o "$stage/$file" ||
      install_die "Failed to download: $base_url/$file"
  done
}

install_validate_stage() {
  local stage="$1"

  bash -n "$stage/elo.sh" "$stage"/lib/*.sh ||
    install_die "Downloaded scripts contain syntax errors."
  chmod +x "$stage/elo.sh"
}

install_activate_release() {
  local stage="$1"
  local release_id release current command_path

  release_id="$(date -u +'%Y%m%d%H%M%S')-$$"
  release="$ELO_INSTALL_DIR/releases/$release_id"
  current="$ELO_INSTALL_DIR/current"
  command_path="$ELO_BIN_DIR/elo"

  if [[ -e "$current" && ! -L "$current" ]]; then
    install_die "Path $current exists and is not a symlink."
  fi
  if [[ -e "$command_path" && ! -L "$command_path" ]]; then
    install_die "Path $command_path exists and will not be overwritten."
  fi

  mkdir -p "$release/lib" "$ELO_BIN_DIR"
  cp "$stage/elo.sh" "$release/elo.sh"
  cp "$stage"/lib/*.sh "$release/lib/"
  chmod +x "$release/elo.sh"

  ln -sfn "$release" "$current"
  ln -sfn "$current/elo.sh" "$command_path"

  install_info "Elo installed at $release"
  install_info "Command created at $command_path"

  case ":$PATH:" in
    *":$ELO_BIN_DIR:"*) ;;
    *)
      printf 'warning: add %s to PATH to use the elo command.\n' \
        "$ELO_BIN_DIR" >&2
      ;;
  esac
}

main() {
  install_parse_options "$@"
  ELO_INSTALL_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/elo-install.XXXXXX")"
  trap install_cleanup EXIT

  if [[ -n "$ELO_SOURCE_DIR" ]]; then
    install_copy_local_files "$ELO_INSTALL_STAGE"
  else
    install_download_files "$ELO_INSTALL_STAGE"
  fi

  install_validate_stage "$ELO_INSTALL_STAGE"
  install_activate_release "$ELO_INSTALL_STAGE"
}

main "$@"
