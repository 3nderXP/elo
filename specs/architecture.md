# Architecture

```text
install.sh            install and activate releases
elo.sh                bootstrap and command dispatch
lib/utils.sh          validation, messages, confirmation
lib/help.sh           help text
lib/config.sh         configuration and state persistence
lib/instance.sh       instance lifecycle
lib/link.sh           symlinks, backup, activation, reset, status
```

`elo.sh` must not contain business logic. Functions use the `elo_` prefix;
command handlers use `elo_cmd_`. Sensitive filesystem operations belong in
`lib/link.sh`. `install.sh` must not initialize runtime data or touch
`.minecraft`.
