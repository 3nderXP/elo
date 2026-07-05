# Repository layout

```text
elo/
├── install.sh
├── elo.sh
├── lib/
├── tests/
├── skills/<skill-name>/{SKILL.md,agents,references}
├── specs/
├── README.md
└── initial-feat.md
```

Reusable code belongs in `lib/`, tests in `tests/`, LLM knowledge in valid
skill folders, normative contracts in `specs/`, and human documentation in
README or `docs/`. Runtime data must never be created in the repository.

New modules require a cohesive responsibility, `elo_` functions, explicit
loading, tests, and an architecture update. Generated artifacts must use
specific `.gitignore` rules.
