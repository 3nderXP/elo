# Current limitations

- No concurrent-process lock or transaction journal
- No user-facing rollback command
- One configured `.minecraft` directory
- Modrinth only; no CurseForge provider or provider authentication
- No automatic loader installation
- Orphan cleanup cannot infer optional or external-addon relationships
- No native Windows support
- Human-oriented output only; no JSON
- Shell-level integration and interactive delegation tests; no exhaustive
  per-module unit suite
- English-only CLI until localization is implemented
