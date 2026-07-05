# Layout do repositório

## Estrutura obrigatória

```text
elo/
├── elo.sh
├── install.sh
├── lib/
│   ├── utils.sh
│   ├── help.sh
│   ├── config.sh
│   ├── instance.sh
│   └── link.sh
├── tests/
│   ├── test_elo.sh
│   └── test_install.sh
├── skills/
│   ├── elo-development/
│   │   ├── SKILL.md
│   │   ├── agents/
│   │   │   └── openai.yaml
│   │   └── references/
│   └── git-github-workflow/
│       ├── SKILL.md
│       ├── agents/
│       │   └── openai.yaml
│       └── references/
├── specs/
│   ├── README.md
│   └── <contrato>.md
├── README.md
├── initial-feat.md
└── .gitignore
```

## Regras de localização

- `elo.sh` **DEVE** conter somente bootstrap, ajuda e despacho de comandos.
- `install.sh` **DEVE** instalar os scripts sem executar lógica de negócio.
- Código reutilizável **DEVE** ficar em `lib/`.
- Testes automatizados **DEVEM** ficar em `tests/`.
- Conhecimento operacional para LLMs **DEVE** ficar em
  `skills/<nome-skill>/`, seguindo o formato `SKILL.md`.
- Contratos normativos de implementação **DEVEM** ficar em `specs/`.
- Documentação de uso humano **DEVE** ficar no `README.md` ou em uma futura
  pasta `docs/`; ela **NÃO DEVE** ser colocada em `skills/`.
- Dados de runtime **NÃO DEVEM** ser criados dentro do repositório.

## Adição de módulos

Um novo arquivo em `lib/` **DEVE**:

1. possuir uma responsabilidade coesa que não pertença aos módulos existentes;
2. usar funções prefixadas com `elo_`;
3. ser carregado explicitamente por `elo.sh`;
4. possuir cobertura no teste de integração;
5. ser adicionado ao diagrama de `architecture.md`.

Não criar módulos apenas para reduzir quantidade de linhas. A separação
**DEVE** representar uma fronteira real de responsabilidade.

## Arquivos gerados

Arquivos temporários, estado local de LLMs e dados de execução **NÃO DEVEM**
ser versionados. Novos artefatos gerados **DEVEM** ser adicionados ao
`.gitignore` somente com padrões específicos, evitando ignorar diretórios
legítimos inteiros.
