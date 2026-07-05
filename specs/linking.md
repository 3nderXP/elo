# Symlinks and backups

An Elo-owned symlink requires a `LINKED_<folder>` record, a symlink at the
expected `.minecraft` path, and an exact target under the recorded instance.
Refuse automatic removal on any mismatch.

Keep at most one original backup per managed folder. Backups belong to the
configured `.minecraft`, not an instance. Link and switch must never overwrite
them. Reset restores `backed_up` paths and leaves `absent` or `removed` paths
missing.

Record state in an order that preserves recovery after failure.
