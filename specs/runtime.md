# Runtime

- Bash `.sh` scripts
- Linux and macOS MVP
- Bash 3.2 compatibility where practical
- Strict mode in executables and tests
- Standard utilities: `mv`, `rm`, `ln`, `readlink`, `mktemp`, `date`, `stat`,
  `awk`, `sed`, `wc`, `cat`, `kill`, and `sleep`
- `curl` required for remote installation, updates, and provider downloads
- Gum v0.17.0 is copied or installed into Elo's private user-space tools
  directory and powers the no-argument interactive interface
- `tar` plus `sha256sum` or `shasum` is required for verified Gum installation
- `jq` required only for provider API commands
- No authentication required for public Modrinth API access
