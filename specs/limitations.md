# Current limitations

- No concurrent-process lock or transaction journal
- No user-facing rollback command
- One configured `.minecraft` directory
- Root instance files and pack-managed trees (`options.txt`, `servers.dat`,
  `icon.png`, `data`, `defaultconfigs`, `kubejs`, `scripts`) are tracked per
  instance through `MANAGED_PATHS`; transient logs, caches, crash reports and
  screenshots remain unmanaged
- Modrinth only; no CurseForge provider or provider authentication
- No automatic loader installation
- `.mrpack` overrides outside the supported managed paths are skipped
- Shader ZIP installation does not install or configure Iris or OptiFine; Elo
  only uses that platform choice to resolve compatible provider versions
- Orphan cleanup cannot infer optional or external-addon relationships
- Cached list status relies on portable file metadata fingerprints; destructive
  addon operations always bypass it and recalculate SHA-512
- No native Windows support
- Custom terminal executables must support direct, `--`, or `-e` program
  invocation
- Human-oriented output only; no JSON
- Shell-level integration and interactive delegation tests; no exhaustive
  per-module unit suite
- English-only CLI until localization is implemented
