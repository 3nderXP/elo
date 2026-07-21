# Testing

`tests/test_elo.sh` covers instance management, backups, replace mode, external
symlinks, active-instance removal, paths with spaces, help, and confirmations.
`tests/test_install.sh` covers isolated installation, latest-stable updates,
exact pre-release updates, and two-release retention with a local fake GitHub
transport. It also verifies private Gum installation, legacy global-Gum
preservation, Linux and macOS graphical-shortcut creation, detected-terminal
persistence, launcher delegation, shortcut cleanup, and self-uninstallation.

`tests/test_provider.sh` covers provider search, dependency planning and
installation, registry scanning, adoption, and safe addon removal using an
offline fake Modrinth transport. It also verifies linear inventory behavior,
partial final pages, persistent integrity-cache reuse, directed rehashing after
file changes, cache removal with an instance, type-aware loader filtering, and
per-installation shader platform resolution.

`tests/test_mrpack.sh` builds offline `.mrpack` fixtures and covers provider API
resolution and archive download, direct local installation, empty-instance
metadata adoption, non-empty-instance warnings, client file selection, optional
files, layered overrides, registry metadata, path traversal rejection, hash
failures, existing-instance protection, and atomic cleanup.

`tests/test_interactive.sh` uses deterministic Gum-response stubs to verify
that interactive menus expose the CLI operations and delegate their selected
options to the existing command handlers. It also covers paginated list wiring,
page boundaries, contextual Previous/Next navigation, adjacent-page snapshots,
First/Last jumps, cursor memory, lazy provider and addon pages, background
prefetch, cache invalidation, native table rendering, and native addon-file
selection. It does not contact providers or access a real terminal.

Tests must use temporary `ELO_HOME` and `.minecraft` roots, remain offline, and
clean only their own temporary data.

```bash
bash -n install.sh elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
./tests/test_provider.sh
./tests/test_mrpack.sh
./tests/test_install.sh
./tests/test_interactive.sh
```
