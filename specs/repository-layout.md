# Repository layout

```text
elo/
├── install.sh
├── elo.sh
├── assets/branding/{README.md,banner.png,banner-frame.png,logo.png,elo.asc,shortcut-icon.png}
├── site/
├── lib/
├── tests/
├── skills/<skill-name>/{SKILL.md,agents,references}
├── specs/
├── README.md
└── initial-feat.md
```

Reusable code belongs in `lib/`, brand artwork in `assets/branding/`, the
static project website in `site/`, tests in `tests/`, LLM knowledge in valid
skill folders, normative contracts in `specs/`, and human documentation in
README or `docs/`. Runtime data must never be created in the repository.

`site/` is the GitHub Pages publishing root. It MUST stay plain HTML, CSS, and
vanilla JavaScript with no build step, no bundler, no external runtime
dependency, and no tracking. It MUST resolve every asset through relative
paths, because GitHub Pages serves nothing above the selected root, so brand
artwork used by the website is copied into `site/assets/img/`. The website
palette MUST stay aligned with the interactive theme colors in
`lib/interactive.sh`, and its ASCII wordmark MUST be the byte-exact content of
`assets/branding/elo.asc`.

New modules require a cohesive responsibility, `elo_` functions, explicit
loading, tests, and an architecture update. Generated artifacts must use
specific `.gitignore` rules.

Feature action plans may remain at repository root while active. Normative
behavior remains in `specs/`; plans do not override specifications.
