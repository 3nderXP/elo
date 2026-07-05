# Safety invariants

- Validate instance and managed-folder names before path composition.
- Never remove an external or divergent symlink.
- Never overwrite an original backup.
- Never execute `.conf` files.
- Require confirmation for replace mode and instance removal.
- Keep recovery state after reset failures.
- `ACTIVE_INSTANCE`, `LINKED_*`, `ORIGINAL_*`, symlinks, and backups must agree.
