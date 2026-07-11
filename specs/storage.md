# Storage

```text
~/.elo/
├── config.conf
├── state.conf
├── instances/<instance-name>/{instance.conf,addons.conf,mods,resourcepacks,shaderpacks,config}
└── backups/original/<folder>.bak
```

`ELO_HOME` overrides the root. `.conf` files contain one `KEY=VALUE` pair per
line and are parsed as data. Values cannot contain newlines.

`config.conf` stores `MINECRAFT_PATH`, `ACTIVE_INSTANCE`, and
`MANAGED_FOLDERS`. `state.conf` stores `LINKED_<folder>` and
`ORIGINAL_<folder>`, whose values are `backed_up`, `absent`, or `removed`.

`addons.conf` records provider/project IDs plus slug, display name, resolved
version, filename, SHA-512, addon type, and dependency status. It is parsed as
data. External files are discovered by scanning and are not persisted.
