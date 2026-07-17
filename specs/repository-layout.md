# Repository layout

```text
elo/
├── install.sh
├── elo.sh
├── assets/branding/{README.md,banner.png,banner-frame.png,logo.png,elo.asc}
├── lib/
├── tests/
├── skills/<skill-name>/{SKILL.md,agents,references}
├── specs/
├── README.md
└── initial-feat.md
```

Reusable code belongs in `lib/`, brand artwork in `assets/branding/`, tests in
`tests/`, LLM knowledge in valid skill folders, normative contracts in `specs/`,
and human documentation in README or `docs/`. Runtime data must never be created
in the repository.

New modules require a cohesive responsibility, `elo_` functions, explicit
loading, tests, and an architecture update. Generated artifacts must use
specific `.gitignore` rules.

Feature action plans may remain at repository root while active. Normative
behavior remains in `specs/`; plans do not override specifications.
