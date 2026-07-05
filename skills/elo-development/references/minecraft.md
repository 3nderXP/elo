# Minecraft domain

The MVP manages `.minecraft/mods`, `resourcepacks`, `shaderpacks`, and
`config`. Launchers remain unaware of Elo and follow normal paths.

Instances live under `$ELO_HOME/instances/<instance-name>/`. Instance data is
not original backup data. Versions and loaders are metadata only; Elo does not
install Minecraft, loaders, mods, or dependencies.

Real folders found before activation belong to the configured `.minecraft`.
`reset` restores them. Switching instances never creates a new original.
