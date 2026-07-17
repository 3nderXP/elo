# Safety invariants

- Validate instance and managed-folder names before path composition.
- Never remove an external or divergent symlink.
- Never overwrite an original backup.
- Never execute `.conf` files.
- Require confirmation for replace mode and instance removal.
- Keep recovery state after reset failures.
- `ACTIVE_INSTANCE`, `LINKED_*`, `ORIGINAL_*`, symlinks, and backups must agree.
- Self-uninstall must validate the active installed release and installer-owned
  command links before removal.
- Preserve `ELO_HOME` unless `--purge` is explicit, the directory has initialized
  Elo state, and the path is not `/` or `$HOME`.
- Keep Gum private to the installation. Preserve a functional standalone copy
  when migrating a legacy global Gum symlink during self-uninstall.
- Keep interactive list snapshots under an Elo-owned `mktemp` directory and
  remove only that validated directory when the interactive process exits.
