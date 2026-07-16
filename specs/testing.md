# Testing

`tests/test_elo.sh` covers instance management, backups, replace mode, external
symlinks, active-instance removal, paths with spaces, help, and confirmations.
`tests/test_install.sh` covers isolated installation, latest-stable updates,
exact pre-release updates, and two-release retention with a local fake GitHub
transport. It also verifies private Gum installation, legacy global-Gum
preservation, and self-uninstallation.

`tests/test_provider.sh` covers provider search, dependency planning and
installation, registry scanning, adoption, and safe addon removal using an
offline fake Modrinth transport.

`tests/test_interactive.sh` uses deterministic Gum-response stubs to verify
that interactive menus expose the CLI operations and delegate their selected
options to the existing command handlers. It does not contact providers or
access a real terminal.

Tests must use temporary `ELO_HOME` and `.minecraft` roots, remain offline, and
clean only their own temporary data.

```bash
bash -n install.sh elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
./tests/test_provider.sh
./tests/test_install.sh
./tests/test_interactive.sh
```
