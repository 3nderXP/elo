# specs/skills/development-rules.md

## Development Rules — Elo

This document centralizes the non-negotiable rules for development in the Elo repository. Agents must consult before any change.

---

## 1. Branches and Commits

- **Main branch**: `develop`
- **Features**: `feat/<name>` from `develop`
- **Commits**: Conventional Commits
- **Pre-commit**: `git diff --check` required

---

## 2. Mandatory Validation (before PR/commit)

```bash
# Bash syntax
bash -n install.sh elo.sh lib/*.sh tests/*.sh

# JS syntax
node --check site/assets/js/*.js site/assets/i18n/*.js

# HTML/CSS (see scripts/validate-site.py if available)
python3 -c "import re, pathlib; ..."

# Tests
./tests/test_elo.sh          # 11 tests
./tests/test_interactive.sh  # 1 test
./tests/test_install.sh      # 6 tests

# Git
git diff --check
```

---

## 3. Design System (site/)

### Palette (from `lib/interactive.sh`)
| Token | Hex | Usage |
|-------|-----|-------|
| `--grass` | `#84A66A` | Accents, cursor, success |
| `--wood` | `#9A7252` | Flags, warnings |
| `--sky` | `#78A9C4` | Titles, links |
| `--text` | `#F1F3EE` | Primary text |
| `--muted` | `#9AA7A0` | Secondary text |
| `--dim` | `#6B7C72` | Labels, numerals |
| `--alert` | `#E8B339` | Alerts, collisions |
| `--bg` | `#121815` | Background |
| `--panel` | `#18211B` | Panels |
| `--raised` | `#1E2A22` | Raised elements |
| `--line` | `#2A382F` | Borders |
| `--line-soft` | `#222E26` | Subtle dividers |

### Visual rules
- **Typography**: mono everywhere (`--mono`), no display/body font
- **Borders**: 1px only, radius ≤ 4px
- **Forbidden**: gradients, glows, glassmorphism, drop shadows, scroll-reveal, marquee, badges
- **Accent colors**: labels, cursors, code only — never fills
- **Numbered sections** with `// label` in left gutter

### Texture and grids (allowed)
- 1px hairlines via `repeating-linear-gradient` (alpha ≤ 5%)
- Fine grain via inline SVG `feTurbulence` (no external request)
- Always masked (`mask-image`) to fade before reaching text
- Applied to specific sections only, not entire page

---

## 4. Copy and i18n

### Structure
| Language | Where | Format |
|----------|-------|--------|
| EN (source) | Inline in HTML | `data-i18n`, `data-i18n-aria-label`, `data-i18n-content` |
| PT-BR | `site/assets/i18n/pt-BR.js` | JS module registering into `window.ELO_I18N["pt-BR"]` |

### Rules
- EN = source of truth, inline in HTML
- PT-BR = JS catalog (not JSON, works in `file://`)
- Missing keys = fallback to EN
- `tui.subtitle` and `tui.active` = actual CLI output (do not translate)
- PT-BR natural, not literal translation

### i18n attributes
| Attribute | Applies to |
|-----------|------------|
| `data-i18n` | `innerHTML` of element |
| `data-i18n-aria-label` | `aria-label` |
| `data-i18n-content` | `content` attribute (meta description) |

---

## 5. Accuracy Rules (zero invention)

### Sources of truth
| Content | Source |
|---------|--------|
| Menus (main, Instances, Addons, System) | `lib/interactive.sh` |
| `elo status` output and columns | `elo_cmd_status` in `lib/link.sh` |
| Managed folder names | `ELO_DEFAULT_MANAGED_FOLDERS` in `lib/config.sh:12` |
| Link states and ORIGINAL | `lib/link.sh` |
| Commands shown in example | repository `README.md` |

### `elo status` format
```bash
printf '%-16s %-20s %-12s %s\n' "FOLDER" "LINK" "ORIGINAL" "STATE"
```
Real states: `ok`, `broken link`, `divergent link`, `missing link`, `instance mismatch`, `external symlink`, `real directory`, `unmanaged`

---

## 5. Prohibited Claims (don't promise what doesn't exist)

| Claim | Reality | Source |
|-------|---------|--------|
| "Atomic switching" / "transactional" | ❌ `elo_activate_instance` links sequentially, no journal | `specs/limitations.md:3`, `lib/link.sh:134` |
| Content-addressed storage / dedup / hardlinks | ❌ Don't exist | grep `cas\|hardlink\|dedup` = 0 |
| Java/Minecraft/loader installation | ❌ Metadata only | `specs/limitations.md:11` |
| Rollback command | ❌ Doesn't exist | `specs/limitations.md:4` |
| JSON output | ❌ Human-only | `specs/limitations.md:21` |

---

## 7. Launchers — Positioning

**Elo is NOT a launcher, doesn't replace one.**

- **Most don't manage modpacks**: vanilla, Legacy Launcher, Shiginima, etc.
- **Some manage via profiles**: Prism, PolyMC, MultiMC
- **Elo = content layer**: points existing `.minecraft` to different folders
- **Pitch**: "Keep your launcher, fix your mod folder"
- **Not limited to one ecosystem**: works with any launcher reading normal `.minecraft`

---

## 8. Terminal Simulation (site/assets/js/terminal.js)

### Behavior
- **`prompt` phase**: menu hidden, types `elo`, Enter opens menu
- **`menu` phase**: `↑↓↵esc` navigation, click = Enter
- **`out` phase**: shows real output (status, collision, install)
- **ESC in `out`** = hides output, returns to menu cleanly
- **Autoplay**: runs once on scroll into view, stops on any interaction
- **Loop**: restarts after 2.5s if user didn't interact
- **Reduced motion**: no autoplay, renders final state

### Real outputs (mocked in simulation, but verbatim text)
- `elo status` — full table (57 chars, fits terminal)
- `elo addons install` — progress lines + installed
- `collision` — real error line

---

## 9. Data Structure (reference)

```
~/.elo/
├── config.conf          # MINECRAFT_PATH, ACTIVE_INSTANCE, etc.
├── state.conf           # LINKED_*, ORIGINAL_*
├── instances/<name>/    # mods, resourcepacks, shaderpacks, config, saves, instance.conf, addons.conf
├── cache/addons/        # integrity (not blobs)
└── backups/original/    # at-most-once, never overwritten
```

---

## 10. Pre-Commit Checklist

- [ ] `bash -n` passes
- [ ] `node --check` passes all JS
- [ ] `git diff --check` clean
- [ ] Tests: 11/11, 1/1, 6/6
- [ ] HTML validates (tags, IDs, anchors)
- [ ] CSS: balanced braces, 0 dead rules
- [ ] i18n: keys match, 0 orphans
- [ ] ASCII: 3 slots, byte-exact
- [ ] ASCII injected via `scripts/inject-ascii.py`
- [ ] Claims reviewed against prohibited list
- [ ] Launcher positioning correct