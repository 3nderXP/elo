# Filesystem safety

Own a symlink only when state records it, the path is a symlink, and its target
exactly matches the recorded instance. Refuse removal on divergence.

Store originals at `$ELO_HOME/backups/original/<folder>.bak`. Keep at most one
original per folder, never overwrite it, and restore it with `mv`.

Original states are `backed_up`, `absent`, and `removed`. Do not clear recovery
state before its filesystem operation completes.

Use backup mode by default. Require explicit confirmation for replace mode and
instance removal. Never auto-repair external paths.
