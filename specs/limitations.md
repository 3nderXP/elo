# Current limitations

- No concurrent-process lock or transaction journal
- No user-facing rollback command
- One configured `.minecraft` directory
- Modrinth only; no CurseForge provider or provider authentication
- No automatic loader installation
- Dependency cleanup is explicit; uninstall does not infer shared orphans
- No native Windows support
- Human-oriented output only; no JSON
- Integration tests only; no per-module unit suite
- English-only CLI until localization is implemented
