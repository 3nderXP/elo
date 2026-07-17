# Storage

```text
~/.elo/
├── config.conf
├── state.conf
├── instances/<instance-name>/{instance.conf,addons.conf,mods,resourcepacks,shaderpacks,config}
├── cache/addons/<instance-name>/<addon-key-hash>.conf
└── backups/original/<folder>.bak
```

`ELO_HOME` overrides the root. `.conf` files contain one `KEY=VALUE` pair per
line and are parsed as data. Values cannot contain newlines.

`config.conf` stores `MINECRAFT_PATH`, `ACTIVE_INSTANCE`, `MANAGED_FOLDERS`,
and `PREFERRED_PROVIDER`. `state.conf` stores `LINKED_<folder>` and
`ORIGINAL_<folder>`, whose values are `backed_up`, `absent`, or `removed`.

`addons.conf` records provider/project IDs plus slug, display name, resolved
version, filename, SHA-512, addon type, and dependency status. It is parsed as
data. Managed entries also store dependency project keys for orphan
reachability. External files are discovered by scanning and are not persisted.

`cache/addons` contains derived integrity results for managed addon files. Each
entry records a schema version, addon key, expected and observed SHA-512,
portable file fingerprint, and last displayed state. Cache files are parsed as
data, written atomically, invalidated on registry changes, and removed with
their instance. They are never authoritative for destructive operations.
