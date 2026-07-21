# Elo testing

Create temporary `ELO_HOME` and `.minecraft` roots. Never access real user
data. Cover original, absent, replaced, external, broken, and divergent paths;
instance switching; reset; spaces in paths; and backup-preserving failures.

Run:

```bash
bash -n install.sh elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
./tests/test_provider.sh
./tests/test_mrpack.sh
./tests/test_install.sh
./tests/test_interactive.sh
```

Keep tests deterministic, offline, and dependency-free.
