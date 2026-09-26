# Elo landing page

Static project website for [Elo](https://github.com/3nderXP/elo). Plain HTML,
CSS, and vanilla JavaScript — no build step, no bundler, no external runtime
dependency, no analytics.

## Publish with GitHub Pages

This folder is designed to be the published root:

1. Push the folder to the repository.
2. Open **Settings → Pages**.
3. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
4. Select the publishing branch and use `/ (root)` as the folder.
5. Save. The site is served from `https://3nderxp.github.io/elo/`.

`.nojekyll` is already present, so Jekyll will not strip any asset.

If the repository is a fork, the published URL follows the fork's owner and
name, for example `https://<user>.github.io/elo/`.

## Local preview

Any static file server works:

```bash
python3 -m http.server --directory site 8080
```

Then open <http://localhost:8080>.

Opening `site/index.html` directly from disk also works, since every asset path
is relative. The GitHub release lookup in `assets/js/main.js` uses the public
REST API, fails silently offline, and never blocks rendering.

## Structure

```text
site/
├── index.html
├── .nojekyll
└── assets/
    ├── css/style.css
    ├── i18n/pt-BR.js
    ├── js/{main,i18n,terminal}.js
    └── img/{icon,favicon,apple-touch-icon}.png, og.jpg
```

`assets/img/` holds optimized copies of `assets/branding/`, because files
outside the published root are not served by GitHub Pages. Regenerate them after
a brand change:

```bash
convert assets/branding/shortcut-icon.png -resize 512x512 -strip -colors 128 \
  site/assets/img/icon.png
convert site/assets/img/icon.png -resize 180x180 -strip -colors 128 \
  site/assets/img/apple-touch-icon.png
convert site/assets/img/icon.png -resize 32x32 -strip -colors 64 \
  site/assets/img/favicon.png
convert assets/branding/banner.png -resize 1200x -strip -quality 86 \
  site/assets/img/og.jpg
```

The ASCII wordmark in `index.html` is the byte-exact content of
`assets/branding/elo.asc`. Replace it mechanically; leading and trailing spaces
are structural. `scripts/inject-ascii.py` rewrites every `data-ascii-logo` slot
from that source, so run it after a brand change instead of hand-editing the
three copies:

```bash
python3 scripts/inject-ascii.py
```

## Design system

The palette is the interactive interface theme from `lib/interactive.sh`, so the
website and the terminal application read as the same product.

| Token | Value | Terminal source |
| --- | --- | --- |
| grass | `#84A66A` | `ELO_UI_GRASS` |
| wood | `#9A7252` | `ELO_UI_WOOD` |
| sky | `#78A9C4` | `ELO_UI_SKY` |
| text | `#F1F3EE` | `ELO_UI_TEXT` |
| muted | `#9AA7A0` | `ELO_UI_MUTED` |
| panel | `#18211B` | `ELO_UI_DARK` |
| alert | `#E8B339` | `ELO_UI_ALERT` |

The visual language is technical documentation, not a product page. Concretely:

- monospace for everything, including prose; no display or body font;
- 1px borders as the only separator, corner radius 4px or less;
- no glows, no glassmorphism, no drop shadows, no colored gradients;
- no scroll-reveal animations, no marquee, no badge wall;
- accent colors are used for labels, cursors and code, never for fills;
- every section is numbered and carries a `// label` in the left gutter.

Texture is allowed, decoration is not. The page uses hairline grids and a
single fine grain layer:

| Utility | Where | What |
| --- | --- | --- |
| `.grain` | once, last child of `<main>` | 160px `feTurbulence` tile at 4.5% alpha, fixed |
| `.grid-fade` | hero | 56px grid, radial mask anchored top-right |
| `.grid-fade--left` | `01 why` | 48px grid, vertical fade |
| `.grid-fade--center` | `03 instances` | 64px grid, radial mask, sits behind the directory trees |
| `.grid-fade--edge` | `04 safety` | horizontal hairlines only, masked to the left edge |
| `.scanlines` | the hero terminal | 3px horizontal hairlines |

Rules for adding more: strokes stay 1px, alpha stays at or below
`--hairline` (`rgba(168, 199, 180, 0.05)`), and every pattern needs a mask so it
fades before it reaches text. Large flat fields are deliberate; a grid that
runs edge to edge behind copy is a bug.

## Accuracy rules

The terminal blocks in `index.html` are transcriptions, not illustrations.
Before editing one, read the source it claims to come from and copy the strings
verbatim.

| Block | Source of truth |
| --- | --- |
| Main menu, `Instances` / `Addons` / `System` submenus | `lib/interactive.sh` |
| `elo status` output and its columns | `elo_cmd_status` in `lib/link.sh` |
| Managed folder names | `ELO_DEFAULT_MANAGED_FOLDERS` in `lib/config.sh` |
| Link states and `ORIGINAL` values | `lib/link.sh` |
| Commands shown in the example | repository `README.md` |

`printf '%-16s %-20s %-12s %s\n'` in `elo_cmd_status` fixes the column widths of
the plain-text status table.

### Claims to keep honest

The site is not allowed to describe features the code does not have. These came
up while writing the copy, and each one is a trap:

- **Do not say "atomic switching" or "transactional".** `elo_activate_instance`
  (`lib/link.sh:134-183`) links one folder at a time, and
  `specs/limitations.md:3` states there is no lock and no transaction journal.
  The site says "switching is a relink", which is what actually happens.
- **Do not imply content-addressed storage, dedup, or hardlinks.** They do not
  exist. Each instance holds real copies; `~/.elo/cache/addons/` stores
  integrity results, not blobs.
- **Do not promise loaders, Java, or Minecraft installs.** `loader` and
  `version` are metadata strings (`lib/instance.sh:59-63`).
- **Do not promise a rollback command.** There is none
  (`specs/limitations.md:4`).
- **Elo does not replace a launcher, and must not say it does.** It never
  touches profiles, Java, accounts or the game. It relinks five folders inside
  an existing `.minecraft`. The pitch is "keep your launcher", not "abandon
  your launcher".

## Positioning

The reference competitors are Prism Launcher, PolyMC and MultiMC. The honest
framing, and the one the code supports:

- a launcher manages the game — Java, versions, accounts, launching;
- Elo manages content inside the folder — mods, resource packs, shaders, config
  and saves;
- the two do not overlap, and Elo does not ask you to give up the launcher.

The differentiators that are actually implemented and therefore safe to claim:
SHA-512 verification of every managed file (`lib/provider.sh:166`), recursive
dependency resolution (`:411`), collision detection that hard-blocks
(`:517`), orphan dependency GC (`:1127`), adoption of external addons without
moving them (`:1048`), validated `.mrpack` import with host allowlist and
SHA-512 (`lib/mrpack.sh:41`), and `elo status` diagnostics across eight link
states (`lib/link.sh:316`).

## Languages

English is the source language and lives inline in `index.html`, so the page is
complete with JavaScript disabled. Translations are catalogs under
`assets/i18n/<tag>.js` that register into `window.ELO_I18N[tag]`.

| Attribute | Applies to |
| --- | --- |
| `data-i18n` | `innerHTML` of the element |
| `data-i18n-aria-label` | `aria-label` of the element |
| `data-i18n-content` | `content` attribute, for `<meta name="description">` |

- The switcher is a `[data-lang]` element; `assets/js/i18n.js` sets
  `document.documentElement.lang` and persists the choice in `localStorage`
  under `elo.lang`.
- First visit follows `navigator.languages`, then falls back to `en`.
- A missing key keeps the English text. Never rename a key without updating
  both `index.html` and every catalog.
- Catalogs are `.js`, not `.json`, so the page also works from `file://`, where
  `fetch` of a local JSON file is blocked by the origin rules.
- `tui.subtitle` and `tui.active` are deliberately untranslated: they are
  verbatim `lib/interactive.sh` output, and the CLI is English-only today.
  Translate them only in the same change that localizes the CLI.

Adding a language means adding `assets/i18n/<tag>.js` and the `[data-lang]`
link. Nothing else needs to change.

## Interactive terminal

The hero terminal is a live simulation, not a recording. `assets/js/terminal.js`
holds the menu tree transcribed from `lib/interactive.sh`.

It runs in two phases, and the order matters:

1. `prompt` — the command line is empty and **the menu is hidden**. Typing fills
   the command; nothing is selectable.
2. `menu` — only after the command is exactly `elo` and Enter is pressed. This
   matches the real entry point, since bare `elo` is what opens the UI
   (`elo.sh:85-88`).

Autoplay runs once when the terminal scrolls into view, walks the tree, and
hands over on any key press. The keys are real: printable characters type into
the prompt, Backspace deletes, Enter opens the menu, and then `↑ ↓ ↵ esc`, `Home`
and `End` navigate it. Clicking an option works too.

Accessibility: the screen is a focusable `role="listbox"`, each option is a
`role="option"` with `aria-selected`, and `aria-activedescendant` tracks the
cursor, so the interaction is announced rather than purely visual. Under
`prefers-reduced-motion: reduce` autoplay never starts; the terminal renders in
its resting state with the command already entered.

The `80×24` in the title bar is set dressing. The rendered menu is not a real
framebuffer and does not model wrapping.

## Maintaining content

- Section order and copy follow the repository `README.md`. Keep both in sync
  when commands, flags, or supported systems change.
- The authoritative command reference is `specs/cli-contract.md` and
  `elo help`. The site deliberately shows only a few commands, since a full
  table belongs in the README.
- The `v0.6.1` strings are static; the header also reports the latest release
  through the GitHub API at runtime and degrades silently.
- `og:image` is a relative path. Replace it with an absolute URL if a specific
  canonical domain is chosen.
- All tracked text is English, per `specs/development-rules.md`. The one
  documented exception is `assets/i18n/pt-BR.js`: it is a locale catalog, not
  product copy, and it exists so the site and a future multilingual CLI share
  the same key names. `index.html` itself stays English.

