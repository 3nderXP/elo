#!/usr/bin/env bash

set -euo pipefail

ELO_REPOSITORY="${ELO_REPOSITORY:-3nderXP/elo}"
ELO_REF="${ELO_REF:-main}"
ELO_INSTALL_DIR="${ELO_INSTALL_DIR:-$HOME/.local/share/elo}"
ELO_BIN_DIR="${ELO_BIN_DIR:-$HOME/.local/bin}"
ELO_SOURCE_DIR=""
ELO_INSTALL_STAGE=""
ELO_GUM_VERSION="${ELO_GUM_VERSION:-0.17.0}"
ELO_GUM_REPOSITORY="${ELO_GUM_REPOSITORY:-charmbracelet/gum}"
ELO_GUM_FORCE_INSTALL="${ELO_GUM_FORCE_INSTALL:-0}"
ELO_GUM_PATH=""
ELO_TERMINAL="${ELO_TERMINAL:-}"
ELO_TERMINAL_ID=""
ELO_TERMINAL_COMMAND=""
ELO_TERMINAL_MODE=""
ELO_SHORTCUT_ENABLED=""
ELO_SHORTCUT_EXPLICIT=0
ELO_SHORTCUT_CONFIGURED=0
ELO_SHORTCUT_FORCE_SETUP=0
ELO_APPLICATIONS_DIR="${ELO_APPLICATIONS_DIR:-}"
ELO_SHORTCUT_PATH=""
ELO_PREVIOUS_SHORTCUT_PATH=""
ELO_WARP_CONFIG_PATH=""
ELO_PREVIOUS_WARP_CONFIG_PATH=""
[[ -n "$ELO_TERMINAL" ]] && ELO_SHORTCUT_EXPLICIT=1

ELO_INSTALL_FILES=(
  "elo.sh"
  "lib/utils.sh"
  "lib/help.sh"
  "lib/config.sh"
  "lib/instance.sh"
  "lib/link.sh"
  "lib/update.sh"
  "lib/self.sh"
  "lib/provider_modrinth.sh"
  "lib/provider.sh"
  "lib/mrpack.sh"
  "lib/interactive.sh"
  "lib/launcher.sh"
  "assets/branding/elo.asc"
  "assets/branding/shortcut-icon.png"
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
  --terminal <command>      Terminal used by the graphical shortcut
  --configure-shortcut     Open the graphical shortcut setup again
  --no-shortcut             Do not create a graphical application shortcut
  --help                    Show this help

Equivalent environment variables:
  ELO_INSTALL_DIR, ELO_BIN_DIR, ELO_REPOSITORY, ELO_REF, ELO_GUM_VERSION,
  ELO_TERMINAL, ELO_APPLICATIONS_DIR
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
      --terminal)
        install_require_value "$1" "${2:-}"
        ELO_TERMINAL="$2"
        ELO_SHORTCUT_EXPLICIT=1
        shift 2
        ;;
      --configure-shortcut)
        ELO_SHORTCUT_FORCE_SETUP=1
        ELO_SHORTCUT_EXPLICIT=1
        shift
        ;;
      --no-shortcut)
        ELO_SHORTCUT_ENABLED=0
        ELO_SHORTCUT_EXPLICIT=1
        shift
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

install_gum_platform() {
  local os architecture

  os="$(uname -s)"
  architecture="$(uname -m)"
  case "$os" in
    Linux) os="Linux" ;;
    Darwin) os="Darwin" ;;
    *) install_die "Gum installation is unsupported on this system: $os" ;;
  esac
  case "$architecture" in
    x86_64 | amd64) architecture="x86_64" ;;
    arm64 | aarch64) architecture="arm64" ;;
    armv7l | armv7) architecture="armv7" ;;
    *) install_die "Gum installation is unsupported on this architecture: $architecture" ;;
  esac
  printf '%s_%s\n' "$os" "$architecture"
}

install_verify_sha256() {
  local file="$1" expected="$2" actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file")"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file")"
  else
    install_die "sha256sum or shasum is required to verify Gum."
  fi
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || install_die "Gum archive failed SHA-256 verification."
}

install_gum() {
  local platform asset base_url archive checksums expected destination temporary extracted existing_gum

  destination="$ELO_INSTALL_DIR/tools/gum-$ELO_GUM_VERSION"
  ELO_GUM_PATH="$destination/gum"
  if [[ "$ELO_GUM_FORCE_INSTALL" != "1" && -x "$ELO_GUM_PATH" && ! -L "$ELO_GUM_PATH" ]]; then
    install_info "Reusing Elo's private Gum: $ELO_GUM_PATH"
    return
  fi
  if [[ -e "$ELO_GUM_PATH" || -L "$ELO_GUM_PATH" ]]; then
    install_die "Path $ELO_GUM_PATH exists and will not be overwritten."
  fi
  if [[ "$ELO_GUM_FORCE_INSTALL" != "1" ]]; then
    existing_gum="$(command -v gum || true)"
    if [[ -n "$existing_gum" && -f "$existing_gum" && ! -L "$existing_gum" ]]; then
      mkdir -p "$destination"
      cp "$existing_gum" "$ELO_GUM_PATH"
      chmod +x "$ELO_GUM_PATH"
      install_info "Copied Gum into Elo's private tools directory."
      return
    fi
  fi
  command -v curl >/dev/null 2>&1 || install_die "curl is required to install Gum."
  command -v tar >/dev/null 2>&1 || install_die "tar is required to install Gum."

  platform="$(install_gum_platform)"
  asset="gum_${ELO_GUM_VERSION}_${platform}.tar.gz"
  base_url="https://github.com/$ELO_GUM_REPOSITORY/releases/download/v$ELO_GUM_VERSION"
  archive="$ELO_INSTALL_STAGE/$asset"
  checksums="$ELO_INSTALL_STAGE/gum-checksums.txt"

  install_info "Downloading Gum v$ELO_GUM_VERSION..."
  curl -fsSL "$base_url/$asset" -o "$archive" ||
    install_die "Failed to download Gum for $platform."
  curl -fsSL "$base_url/checksums.txt" -o "$checksums" ||
    install_die "Failed to download Gum checksums."
  expected="$(awk -v asset="$asset" '$2 == asset { print $1; exit }' "$checksums")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] ||
    install_die "Gum checksum is missing or invalid for $asset."
  install_verify_sha256 "$archive" "$expected"

  temporary="$ELO_INSTALL_STAGE/gum-extracted"
  mkdir -p "$temporary"
  tar -xzf "$archive" -C "$temporary" || install_die "Failed to extract Gum."
  extracted="$temporary/${asset%.tar.gz}/gum"
  [[ -f "$extracted" && ! -L "$extracted" ]] ||
    install_die "The Gum archive does not contain its expected executable."

  mkdir -p "$destination"
  cp "$extracted" "$ELO_GUM_PATH"
  chmod +x "$ELO_GUM_PATH"
  install_info "Gum installed privately at $ELO_GUM_PATH"
}

install_config_get() {
  local file="$1" wanted="$2" key value
  [[ -f "$file" ]] || return 1
  while IFS='=' read -r key value; do
    if [[ "$key" == "$wanted" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done <"$file"
  return 1
}

install_terminal_metadata() {
  local requested="$1" resolved basename id mode label directory

  resolved="$(command -v -- "$requested" 2>/dev/null || true)"
  if [[ -z "$resolved" && "$requested" == */* && -x "$requested" && ! -d "$requested" ]]; then
    directory="$(cd "$(dirname "$requested")" && pwd -P)"
    resolved="$directory/$(basename "$requested")"
  fi
  [[ -n "$resolved" && -x "$resolved" && ! -d "$resolved" ]] || return 1
  basename="$(basename "$resolved")"
  case "$basename" in
    open)
      [[ "$(uname -s)" == "Darwin" ]] || return 1
      id=apple-terminal; mode=mac-terminal; label="Apple Terminal"
      ;;
    warp-terminal) id=warp; mode=warp; label=Warp ;;
    kitty) id=kitty; mode=direct; label=Kitty ;;
    gnome-terminal) id=gnome-terminal; mode=double-dash; label="GNOME Terminal" ;;
    kgx) id=kgx; mode=double-dash; label="GNOME Console" ;;
    konsole) id=konsole; mode=dash-e; label=Konsole ;;
    xfce4-terminal) id=xfce4-terminal; mode=xfce; label="Xfce Terminal" ;;
    mate-terminal) id=mate-terminal; mode=double-dash; label="MATE Terminal" ;;
    tilix) id=tilix; mode=dash-e; label=Tilix ;;
    wezterm) id=wezterm; mode=wezterm; label=WezTerm ;;
    alacritty) id=alacritty; mode=dash-e; label=Alacritty ;;
    foot | footclient) id="$basename"; mode=direct; label=foot ;;
    qterminal) id=qterminal; mode=dash-e; label=QTerminal ;;
    lxterminal) id=lxterminal; mode=dash-e; label=LXTerminal ;;
    xterm) id=xterm; mode=dash-e; label=XTerm ;;
    *) id=custom; mode=dash-e; label="$basename" ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$id" "$resolved" "$mode" "$label"
}

install_detect_terminals() {
  local preferred="" candidate record seen=" " path
  case "${TERM_PROGRAM:-}" in
    WarpTerminal) preferred=warp-terminal ;;
    kitty) preferred=kitty ;;
    WezTerm) preferred=wezterm ;;
  esac
  [[ "$(uname -s)" == "Darwin" ]] && preferred=open
  [[ -n "${GNOME_TERMINAL_SCREEN:-}" ]] && preferred=gnome-terminal
  [[ -n "${KONSOLE_VERSION:-}" ]] && preferred=konsole

  for candidate in "$preferred" open warp-terminal kitty gnome-terminal kgx konsole \
    xfce4-terminal mate-terminal tilix wezterm alacritty foot footclient \
    qterminal lxterminal xterm; do
    [[ -n "$candidate" ]] || continue
    record="$(install_terminal_metadata "$candidate" || true)"
    [[ -n "$record" ]] || continue
    path="$(printf '%s\n' "$record" | awk -F '\t' '{ print $2 }')"
    case "$seen" in *" $path "*) continue ;; esac
    seen="$seen$path "
    printf '%s\n' "$record"
  done
}

install_has_tty() {
  (exec 9<>/dev/tty && [[ -t 9 ]]) 2>/dev/null
}

install_select_custom_terminal() {
  local requested record style
  requested="$("$ELO_GUM_PATH" input --prompt "Terminal command: " \
    --prompt.foreground '#84A66A' --cursor.foreground '#78A9C4' \
    --placeholder.foreground '#9AA7A0' --placeholder "for example: kitty" \
    --width 60 </dev/tty)" || return 1
  [[ -n "$requested" ]] || return 1
  record="$(install_terminal_metadata "$requested" || true)"
  [[ -n "$record" ]] || install_die "Terminal command not found or not executable: $requested"
  IFS=$'\t' read -r ELO_TERMINAL_ID ELO_TERMINAL_COMMAND ELO_TERMINAL_MODE _ <<<"$record"
  if [[ "$ELO_TERMINAL_ID" == "custom" ]]; then
    style="$("$ELO_GUM_PATH" choose --header "How does this terminal execute a program?" \
      --cursor '› ' --cursor.foreground '#84A66A' --header.foreground '#78A9C4' \
      --selected.foreground '#F1F3EE' --selected.background '#9A7252' \
      "-e <program>" "-- <program>" "<program> directly" </dev/tty)" || return 1
    case "$style" in
      "-- <program>") ELO_TERMINAL_MODE=double-dash ;;
      "<program> directly") ELO_TERMINAL_MODE=direct ;;
      *) ELO_TERMINAL_MODE=dash-e ;;
    esac
  fi
}

install_load_shortcut_config() {
  local config="$ELO_INSTALL_DIR/install.conf" configured
  [[ -f "$config" ]] || return 1
  ELO_PREVIOUS_SHORTCUT_PATH="$(install_config_get "$config" SHORTCUT_PATH || true)"
  ELO_PREVIOUS_WARP_CONFIG_PATH="$(install_config_get "$config" WARP_CONFIG_PATH || true)"
  configured="$(install_config_get "$config" SHORTCUT_ENABLED || true)"
  if [[ "$configured" == "0" || "$configured" == "1" ]]; then
    ELO_SHORTCUT_CONFIGURED=1
  fi
  ((ELO_SHORTCUT_EXPLICIT == 0)) || return 0
  ELO_SHORTCUT_ENABLED="$configured"
  ELO_TERMINAL_ID="$(install_config_get "$config" TERMINAL_ID || true)"
  ELO_TERMINAL_COMMAND="$(install_config_get "$config" TERMINAL_COMMAND || true)"
  ELO_TERMINAL_MODE="$(install_config_get "$config" TERMINAL_MODE || true)"
  return 0
}

install_setup_shortcut() {
  local existing=0 interactive=0 detected choice record label
  local -a records=() choices=()

  [[ -f "$ELO_INSTALL_DIR/install.conf" ]] && existing=1
  install_load_shortcut_config || true
  install_has_tty && interactive=1
  if ((existing == 1 && ELO_SHORTCUT_CONFIGURED == 1 && ELO_SHORTCUT_EXPLICIT == 0)); then
    if ((interactive == 0)); then
      return
    fi
    ELO_SHORTCUT_ENABLED=""
  fi
  if ((ELO_SHORTCUT_FORCE_SETUP == 1)); then
    ELO_SHORTCUT_ENABLED=""
    ELO_TERMINAL=""
    ELO_TERMINAL_ID=""
    ELO_TERMINAL_COMMAND=""
    ELO_TERMINAL_MODE=""
  fi
  if [[ "$(uname -s)" != "Linux" && "$(uname -s)" != "Darwin" ]]; then
    ELO_SHORTCUT_ENABLED=0
    ((ELO_SHORTCUT_EXPLICIT == 0)) || install_info "Graphical shortcuts are supported on Linux and macOS only."
    return
  fi
  if [[ -n "$ELO_TERMINAL" ]]; then
    record="$(install_terminal_metadata "$ELO_TERMINAL" || true)"
    [[ -n "$record" ]] || install_die "Terminal command not found or not executable: $ELO_TERMINAL"
    IFS=$'\t' read -r ELO_TERMINAL_ID ELO_TERMINAL_COMMAND ELO_TERMINAL_MODE _ <<<"$record"
    ELO_SHORTCUT_ENABLED=1
    return
  fi
  [[ "$ELO_SHORTCUT_ENABLED" != "0" ]] || return 0

  detected="$(install_detect_terminals)"
  while IFS= read -r record; do
    IFS=$'\t' read -r _ _ _ label <<<"$record"
    [[ -n "$label" ]] || continue
    records+=("$record")
    choices+=("$label")
  done <<<"$detected"

  if ((interactive == 1)); then
    choices+=("Specify another terminal" "Do not create a shortcut")
    choice="$("$ELO_GUM_PATH" choose --header "Choose the terminal for the Elo shortcut" \
      --cursor '› ' --cursor.foreground '#84A66A' --header.foreground '#78A9C4' \
      --selected.foreground '#F1F3EE' --selected.background '#9A7252' \
      --height 14 "${choices[@]}" </dev/tty)" || install_die "Shortcut setup was cancelled."
    case "$choice" in
      "Do not create a shortcut") ELO_SHORTCUT_ENABLED=0; return ;;
      "Specify another terminal")
        install_select_custom_terminal || install_die "Shortcut setup was cancelled."
        ELO_SHORTCUT_ENABLED=1
        return
        ;;
    esac
    for record in "${records[@]}"; do
      IFS=$'\t' read -r ELO_TERMINAL_ID ELO_TERMINAL_COMMAND ELO_TERMINAL_MODE label <<<"$record"
      if [[ "$choice" == "$label" ]]; then
        ELO_SHORTCUT_ENABLED=1
        return
      fi
    done
  elif ((${#records[@]} > 0)); then
    IFS=$'\t' read -r ELO_TERMINAL_ID ELO_TERMINAL_COMMAND ELO_TERMINAL_MODE _ <<<"${records[0]}"
    ELO_SHORTCUT_ENABLED=1
    install_info "Using detected terminal for the shortcut: $ELO_TERMINAL_COMMAND"
    return
  fi
  ELO_SHORTCUT_ENABLED=0
  install_info "No supported terminal was detected; the graphical shortcut was skipped."
}

install_prepare_shortcut_paths() {
  ELO_SHORTCUT_PATH=""
  ELO_WARP_CONFIG_PATH=""
  [[ "$ELO_SHORTCUT_ENABLED" == "1" ]] || return 0
  case "$(uname -s)" in
    Darwin) ELO_SHORTCUT_PATH="${ELO_APPLICATIONS_DIR:-$HOME/Applications}/Elo.app" ;;
    *) ELO_SHORTCUT_PATH="${ELO_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}/elo.desktop" ;;
  esac
  if [[ "$ELO_TERMINAL_MODE" == "warp" ]]; then
    ELO_WARP_CONFIG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/launch_configurations/elo-cli.yaml"
  fi
}

install_validate_shortcut_targets() {
  [[ "$ELO_SHORTCUT_ENABLED" == "1" ]] || return 0
  if [[ -e "$ELO_SHORTCUT_PATH" || -L "$ELO_SHORTCUT_PATH" ]] &&
    ! install_shortcut_is_managed "$ELO_SHORTCUT_PATH"; then
    install_die "Shortcut path exists and is not managed by Elo: $ELO_SHORTCUT_PATH"
  fi
  if [[ -n "$ELO_WARP_CONFIG_PATH" && -e "$ELO_WARP_CONFIG_PATH" ]] &&
    ! grep -Fx '# Managed by the Elo installer.' "$ELO_WARP_CONFIG_PATH" >/dev/null 2>&1; then
    install_die "Warp launch configuration exists and is not managed by Elo: $ELO_WARP_CONFIG_PATH"
  fi
}

install_shortcut_is_managed() {
  local path="$1"
  if [[ -f "$path" && ! -L "$path" ]]; then
    grep -Fx 'X-Elo-Managed=true' "$path" >/dev/null 2>&1
  elif [[ -d "$path" && ! -L "$path" ]]; then
    grep -Fx 'Managed by the Elo installer.' \
      "$path/Contents/Resources/.elo-managed" >/dev/null 2>&1
  else
    return 1
  fi
}

install_remove_managed_shortcut() {
  local path="$1"
  install_shortcut_is_managed "$path" || return 0
  if [[ -d "$path" ]]; then
    rm -rf -- "$path"
  else
    rm -- "$path"
    install_refresh_desktop_database "$(dirname "$path")"
  fi
}

install_refresh_desktop_database() {
  local directory="$1"
  command -v update-desktop-database >/dev/null 2>&1 || return 0
  [[ -d "$directory" ]] || return 0
  update-desktop-database "$directory" >/dev/null 2>&1 || true
}

install_remove_previous_shortcut_files() {
  if [[ -n "$ELO_PREVIOUS_SHORTCUT_PATH" && "$ELO_PREVIOUS_SHORTCUT_PATH" != "$ELO_SHORTCUT_PATH" &&
    ( -e "$ELO_PREVIOUS_SHORTCUT_PATH" || -L "$ELO_PREVIOUS_SHORTCUT_PATH" ) ]]; then
    install_remove_managed_shortcut "$ELO_PREVIOUS_SHORTCUT_PATH"
  fi
  if [[ -n "$ELO_PREVIOUS_WARP_CONFIG_PATH" && "$ELO_PREVIOUS_WARP_CONFIG_PATH" != "$ELO_WARP_CONFIG_PATH" &&
    -f "$ELO_PREVIOUS_WARP_CONFIG_PATH" ]] &&
    grep -Fx '# Managed by the Elo installer.' "$ELO_PREVIOUS_WARP_CONFIG_PATH" >/dev/null 2>&1; then
    rm -- "$ELO_PREVIOUS_WARP_CONFIG_PATH"
  fi
  return 0
}

install_desktop_quote() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/`/\\`/g; s/\$/\\$/g; s/%/%%/g'
}

install_desktop_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g'
}

install_shell_single_quote() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

install_create_macos_icon() {
  local resources="$1" source="$2" iconset="$resources/EloIcon.iconset"
  local size scaled

  if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
      sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
      scaled=$((size * 2))
      sips -z "$scaled" "$scaled" "$source" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    if iconutil -c icns "$iconset" -o "$resources/EloIcon.icns" >/dev/null 2>&1; then
      rm -rf -- "$iconset"
      printf '%s\n' 'EloIcon.icns'
      return
    fi
    rm -rf -- "$iconset"
  fi
  cp "$source" "$resources/EloIcon.png"
  printf '%s\n' 'EloIcon.png'
}

install_create_macos_shortcut() {
  local launcher icon resources executable temporary quoted_launcher icon_name
  launcher="$ELO_INSTALL_DIR/current/lib/launcher.sh"
  icon="$ELO_INSTALL_DIR/current/assets/branding/shortcut-icon.png"
  temporary="$(dirname "$ELO_SHORTCUT_PATH")/.Elo.app.tmp.$$"
  resources="$temporary/Contents/Resources"
  executable="$temporary/Contents/MacOS/Elo"
  quoted_launcher="$(install_shell_single_quote "$launcher")"

  mkdir -p "$resources" "$(dirname "$executable")"
  icon_name="$(install_create_macos_icon "$resources" "$icon")"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf "exec '%s'\n" "$quoted_launcher"
  } >"$executable"
  chmod 0755 "$executable"
  printf '%s\n' 'Managed by the Elo installer.' >"$resources/.elo-managed"
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    printf '%s\n' '<plist version="1.0">' '<dict>'
    printf '%s\n' '  <key>CFBundleDisplayName</key>' '  <string>Elo</string>'
    printf '%s\n' '  <key>CFBundleExecutable</key>' '  <string>Elo</string>'
    printf '%s\n' '  <key>CFBundleIdentifier</key>' '  <string>io.github.3nderxp.elo</string>'
    printf '%s\n' '  <key>CFBundleName</key>' '  <string>Elo</string>'
    printf '%s\n' '  <key>CFBundlePackageType</key>' '  <string>APPL</string>'
    printf '%s\n' '  <key>CFBundleVersion</key>' '  <string>1</string>'
    printf '%s\n' '  <key>CFBundleShortVersionString</key>' '  <string>1.0</string>'
    printf '%s\n' '  <key>CFBundleIconFile</key>' "  <string>$icon_name</string>"
    printf '%s\n' '  <key>LSUIElement</key>' '  <true/>'
    printf '%s\n' '</dict>' '</plist>'
  } >"$temporary/Contents/Info.plist"

  mkdir -p "$(dirname "$ELO_SHORTCUT_PATH")"
  install_remove_managed_shortcut "$ELO_SHORTCUT_PATH"
  mv "$temporary" "$ELO_SHORTCUT_PATH"
}

install_create_shortcut() {
  local launcher icon temporary quoted_launcher quoted_icon yaml_command yaml_home
  install_remove_previous_shortcut_files
  [[ "$ELO_SHORTCUT_ENABLED" == "1" ]] || return 0

  if [[ "$(uname -s)" == "Darwin" ]]; then
    install_create_macos_shortcut
    install_info "Application shortcut created at $ELO_SHORTCUT_PATH"
    return
  fi

  launcher="$ELO_INSTALL_DIR/current/lib/launcher.sh"
  icon="$ELO_INSTALL_DIR/current/assets/branding/shortcut-icon.png"
  mkdir -p "$(dirname "$ELO_SHORTCUT_PATH")"
  quoted_launcher="$(install_desktop_quote "$launcher")"
  quoted_icon="$(install_desktop_string "$icon")"
  temporary="$ELO_SHORTCUT_PATH.tmp.$$"
  {
    printf '%s\n' '[Desktop Entry]'
    printf '%s\n' 'Type=Application'
    printf '%s\n' 'Version=1.0'
    printf '%s\n' 'Name=Elo'
    printf '%s\n' 'Comment=Manage Minecraft instances'
    printf 'Exec="%s"\n' "$quoted_launcher"
    printf 'Icon=%s\n' "$quoted_icon"
    printf '%s\n' 'Terminal=false'
    printf '%s\n' 'Categories=Game;'
    printf '%s\n' 'Keywords=Minecraft;mods;instances;'
    printf '%s\n' 'X-Elo-Managed=true'
  } >"$temporary"
  chmod 0644 "$temporary"
  mv "$temporary" "$ELO_SHORTCUT_PATH"
  install_refresh_desktop_database "$(dirname "$ELO_SHORTCUT_PATH")"

  if [[ "$ELO_TERMINAL_MODE" == "warp" ]]; then
    mkdir -p "$(dirname "$ELO_WARP_CONFIG_PATH")"
    yaml_command="${ELO_BIN_DIR//\'/\'\'}"
    yaml_command="$yaml_command/elo"
    yaml_home="${HOME//\'/\'\'}"
    temporary="$ELO_WARP_CONFIG_PATH.tmp.$$"
    {
      printf '%s\n' '# Managed by the Elo installer.' '---' 'name: Elo CLI' 'windows:'
      printf '%s\n' '  - tabs:' '      - title: Elo' '        layout:'
      printf "          cwd: '%s'\n" "$yaml_home"
      printf '%s\n' '          commands:'
      printf "            - exec: '%s'\n" "$yaml_command"
    } >"$temporary"
    chmod 0644 "$temporary"
    mv "$temporary" "$ELO_WARP_CONFIG_PATH"
  fi
  install_info "Application shortcut created at $ELO_SHORTCUT_PATH"
}

install_write_config() {
  local config="$ELO_INSTALL_DIR/install.conf"
  local temporary="$ELO_INSTALL_DIR/install.conf.tmp.$$"

  case "$ELO_REPOSITORY$ELO_BIN_DIR$ELO_GUM_PATH$ELO_TERMINAL_COMMAND$ELO_SHORTCUT_PATH$ELO_WARP_CONFIG_PATH" in
    *'
'*) install_die "Repository and installation paths cannot contain newlines." ;;
  esac

  {
    printf 'REPOSITORY=%s\n' "$ELO_REPOSITORY"
    printf 'BIN_DIR=%s\n' "$ELO_BIN_DIR"
    printf 'GUM_PATH=%s\n' "$ELO_GUM_PATH"
    printf 'SHORTCUT_ENABLED=%s\n' "${ELO_SHORTCUT_ENABLED:-0}"
    printf 'SHORTCUT_PATH=%s\n' "$ELO_SHORTCUT_PATH"
    printf 'TERMINAL_ID=%s\n' "$ELO_TERMINAL_ID"
    printf 'TERMINAL_COMMAND=%s\n' "$ELO_TERMINAL_COMMAND"
    printf 'TERMINAL_MODE=%s\n' "$ELO_TERMINAL_MODE"
    printf 'WARP_CONFIG_PATH=%s\n' "$ELO_WARP_CONFIG_PATH"
  } >"$temporary"
  mv "$temporary" "$config"
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

  mkdir -p "$release/lib" "$release/assets/branding" "$ELO_BIN_DIR"
  install_write_config
  cp "$stage/elo.sh" "$release/elo.sh"
  cp "$stage"/lib/*.sh "$release/lib/"
  cp "$stage/assets/branding/elo.asc" "$release/assets/branding/elo.asc"
  cp "$stage/assets/branding/shortcut-icon.png" "$release/assets/branding/shortcut-icon.png"
  chmod +x "$release/elo.sh"
  chmod +x "$release/lib/launcher.sh"

  ln -sfn "$release" "$current"
  ln -sfn "$current/elo.sh" "$command_path"

  install_create_shortcut

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
  install_gum
  install_setup_shortcut
  install_prepare_shortcut_paths
  install_validate_shortcut_targets
  install_activate_release "$ELO_INSTALL_STAGE"
}

main "$@"
