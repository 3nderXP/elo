# AGENTS.md — Instructions for AI agents in the Elo repository

## Overview

This repository contains **Elo**, a Minecraft instance manager in Bash. The static landing page lives in `site/` and is published via GitHub Pages.

## How to work in this repo

### Branches and commits
- Main branch: `develop`
- Features in `feat/<name>` from `develop`
- Commits follow Conventional Commits
- `git diff --check` must pass before commit

### Mandatory validation (run before PR/commit)
```bash
# Syntax
bash -n install.sh elo.sh lib/*.sh tests/*.sh
node --check site/assets/js/*.js site/assets/i18n/*.js

# HTML/CSS
python3 -c "import re, pathlib; ..."  # see validator in scripts/

# Tests
./tests/test_elo.sh
./tests/test_interactive.sh
./tests/test_install.sh

# Git
git diff --check
```

### Landing page publishing
- `site/` folder is the GitHub Pages root
- Relative assets only (`assets/...`, no leading `/`)
- `.nojekyll` already present
- `scripts/inject-ascii.py` injects ASCII wordmark from `assets/branding/elo.asc` into `data-ascii-logo` slots
- `scripts/inject-version.py` writes the highest version tag into every `data-repo-version` slot; run on release, never hand-edit the version

### Design system (site/)
- Palette from `lib/interactive.sh`: `--grass`, `--wood`, `--sky`, `--text`, `--muted`, `--panel`, `--alert`
- Typography: mono everywhere (`--mono`)
- Borders 1px, radius ≤ 4px
- No gradients, glows, glassmorphism, drop shadows, scroll-reveal animations, badges
- Grids and texture allowed (see `site/README.md`)

### Copy and i18n
- EN is source of truth, inline in HTML (`data-i18n`)
- PT-BR in `assets/i18n/pt-BR.js` (JS, not JSON, for `file://` compatibility)
- Missing keys = fallback to EN
- `tui.subtitle` and `tui.active` = actual CLI output (do not translate)
- PT-BR natural, not literal translation

### Accuracy rules (site/README.md)
- Terminal blocks = literal transcriptions from code (`lib/interactive.sh`, `lib/link.sh`, etc.)
- Do not invent command output
- `elo status` = 8 real states from `lib/link.sh:316`
- Menus = real strings from `lib/interactive.sh`

### Prohibited claims (see site/README.md)
- ❌ "Atomic switching" / "transactional" — `elo_activate_instance` links sequentially, no journal
- ❌ Content-addressed storage / dedup / hardlinks — don't exist
- ❌ Java/Minecraft/loader installation — metadata only
- ❌ Rollback command — doesn't exist
- ❌ JSON output — human-only

### Launchers — positioning
- Elo is **not a launcher**, doesn't replace one
- Most don't manage modpacks: vanilla, Legacy Launcher, Shiginima, etc.
- Prism/PolyMC/MultiMC use profiles; Elo = content layer
- "Keep your launcher, fix your mod folder"

### Data structure
```
~/.elo/
├── config.conf          # MINECRAFT_PATH, ACTIVE_INSTANCE, etc.
├── state.conf           # LINKED_*, ORIGINAL_*
├── instances/<name>/    # mods, resourcepacks, shaderpacks, config, saves, instance.conf, addons.conf
├── cache/addons/        # integrity (not blobs)
└── backups/original/    # at-most-once, never overwritten
```

### Main commands
| Command | Handler |
|---------|---------|
| (no args) → interactive UI | `elo_ui_run` |
| `init` | `elo_cmd_init` (`lib/config.sh`) |
| `instances` | `elo_dispatch_instances` |
| `addons` | `elo_dispatch_addons` |
| `status` | `elo_cmd_status` (`lib/link.sh`) |
| `update` / `uninstall` / `version` / `help` | respective |

### Helper scripts
- `scripts/inject-ascii.py` — injects ASCII wordmark
- `scripts/inject-version.py` — injects the version into every `data-repo-version` slot
- `scripts/` — only landing page build tools

## Rules for agents

1. **Don't invent command output** — use literal transcriptions
2. **Don't promise non-existent features** — see "Prohibited claims"
3. **Keep i18n synced** — EN in HTML, PT-BR in JS catalog
4. **Tests before commit** — run full suite
3. **Minimalist design** — mono, 1px, ≤4px, no fluff
4. **Launchers** — Elo complements, doesn't replace; most don't manage modpacks
5. **Document decisions** — in `specs/skills/` or `AGENTS.md`