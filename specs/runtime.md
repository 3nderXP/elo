# Runtime

- Bash `.sh` scripts
- Linux and macOS MVP
- Bash 3.2 compatibility where practical
- Strict mode in executables and tests
- Standard utilities: `mv`, `rm`, `ln`, `readlink`, `mktemp`, `date`, `stat`,
  `find`, `awk`, `sed`, `wc`, `cat`, `kill`, and `sleep`
- `curl` required for remote installation, updates, and provider downloads
- `unzip` required for local Modrinth `.mrpack` imports
- Gum v0.17.0 is copied or installed into Elo's private user-space tools
  directory and powers the no-argument interactive interface
- On Linux and macOS, Gum also powers first-install terminal selection for the
  graphical shortcut when a controlling terminal is available
- Gum changes start from the official raw command reference at
  https://raw.githubusercontent.com/charmbracelet/gum/refs/heads/main/README.md
  and MUST be checked against `gum <command> --help` for the pinned v0.17.0
  runtime before implementation
- Gum v0.17.0 provides `spin`, but no native percentage progress-bar command;
  modpack downloads use Elo's ANSI progress bar on TTYs and `info:` progress
  lines when output is not a TTY
- Version migration reports use `gum pager` for large addon sets. Selective
  incompatible-addon removal uses `gum filter --no-limit`, providing a
  searchable multi-select checklist without rendering every choice at once.
- Instance management includes `saves`; each instance has isolated worlds and
  activation backs up the original Minecraft `saves` directory.
- `tar` plus `sha256sum` or `shasum` is required for verified Gum installation
- `jq` required only for provider API commands
- No authentication required for public Modrinth API access

The Linux application shortcut is written under
`${XDG_DATA_HOME:-$HOME/.local/share}/applications`. Supported adapters include
Warp, Kitty, GNOME Terminal and Console, Konsole, Xfce Terminal, MATE Terminal,
Tilix, WezTerm, Alacritty, foot, QTerminal, LXTerminal, and XTerm. A custom
executable can use direct, `--`, or `-e` program invocation. Warp uses its
official launch-configuration URI because it does not accept an arbitrary
program through its normal application executable.

On macOS, the installer writes an `Elo.app` bundle under `~/Applications`.
The bundle uses Apple Terminal by default and contains an installer ownership
marker, executable wrapper, property list, and branded icon. The application
directory remains configurable through `ELO_APPLICATIONS_DIR`.

An installation manifest without shortcut fields is migrated through the
interactive setup. Interactive reinstalls and updates present the choice
again; non-interactive runs preserve the saved choice. `--configure-shortcut`
explicitly requests setup, `--terminal <command>` selects an executable without
prompting, and `--no-shortcut` removes an installer-managed shortcut.
