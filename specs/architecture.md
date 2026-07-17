# Architecture

```text
install.sh            install and activate releases
elo.sh                bootstrap and command dispatch
lib/utils.sh          validation, messages, confirmation
lib/help.sh           help text
lib/config.sh         configuration and state persistence
lib/instance.sh       instance lifecycle
lib/link.sh           symlinks, backup, activation, reset, status
lib/update.sh         release selection and installer delegation
lib/self.sh           installer-owned self-uninstallation
lib/provider.sh       provider routing, addon registry, and lifecycle
lib/provider_modrinth.sh Modrinth API requests and downloads
lib/interactive.sh     Gum UI that delegates to existing command functions
```

`elo.sh` must not contain business logic. Functions use the `elo_` prefix;
command handlers use `elo_cmd_`. Sensitive filesystem operations belong in
`lib/link.sh`. `install.sh` must not initialize runtime data or touch
`.minecraft`.

The installer writes `install.conf` under its installation root with the
repository, command directory, and private Gum path. Update and
self-uninstall commands parse this file as data. The update command delegates
staged download, validation, and atomic activation to the target release's
installer.

Provider modules implement `search`, paginated `search_page`, `project_type`,
`resolve`, `get_dependencies`, and `download` functions. Paginated search
returns the provider's total hit count before its result rows. The provider
manager owns CLI behavior, recursive dependency coordination, `addons.conf`,
and derived addon integrity caches; provider-specific modules do not write
runtime state.
