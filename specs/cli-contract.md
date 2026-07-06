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
elo update [--version <version>] [--yes]
elo help [command]
```

All output must be English. Use `info:`, `warning:`, and `error:` prefixes.
General and command-specific help must explain required fields, defaults,
risks, and examples.

Exit codes: `0` success/consistent, `1` operational failure/inconsistency, and
`2` unknown command. State-changing commands require confirmation; `--yes`
authorizes non-interactive execution.

`elo update` resolves GitHub's latest stable release by default. `--version`
selects an exact SemVer release, including pre-releases; a missing leading `v`
is added. Updates work only from installer-managed releases and activate the
new release only after validation.
After activation, Elo retains the active and immediately previous releases,
then removes older directories that match the managed release layout. Unknown
entries and releases needed for recovery must never be removed.
