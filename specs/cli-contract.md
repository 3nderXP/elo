# CLI contract

```text
elo init --minecraft-path <path>
elo new <instance-name> [--version <version>] [--loader <loader>]
elo link <instance-name> [--mode backup|replace] [--yes]
elo switch <instance-name> [--yes]
elo reset [--yes]
elo list
elo status
elo remove <instance-name> [--reset] [--yes]
elo help [command]
```

All output must be English. Use `info:`, `warning:`, and `error:` prefixes.
General and command-specific help must explain required fields, defaults,
risks, and examples.

Exit codes: `0` success/consistent, `1` operational failure/inconsistency, and
`2` unknown command. State-changing commands require confirmation; `--yes`
authorizes non-interactive execution.
