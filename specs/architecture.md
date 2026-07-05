# Arquitetura

## Módulos

```text
elo.sh
├── lib/utils.sh       validação, mensagens e confirmação
├── lib/help.sh        ajuda geral e ajuda específica por comando
├── lib/config.sh      configuração e persistência do estado
├── lib/instance.sh    ciclo de vida das instâncias
└── lib/link.sh        symlinks, backup, ativação e reset
```

## Responsabilidades

### `elo.sh`

- habilita o modo estrito do Bash;
- carrega os módulos;
- interpreta o comando principal;
- encaminha argumentos para a função correspondente;
- não contém lógica de negócio.

### `lib/utils.sh`

- padroniza mensagens;
- solicita confirmações;
- valida nomes e argumentos;
- resolve caminhos de diretórios existentes.

### `lib/help.sh`

- documenta a notação de argumentos;
- mantém ajuda geral e ajuda específica por comando;
- descreve obrigatoriedade, valores padrão, efeitos e exemplos;
- não executa lógica de negócio.

### `lib/config.sh`

- define os caminhos internos;
- lê e atualiza arquivos `.conf`;
- inicializa o diretório de dados;
- expõe configurações e estado.

### `lib/instance.sh`

- cria metadados e diretórios de instâncias;
- lista instâncias;
- controla a remoção.

### `lib/link.sh`

- valida a propriedade dos symlinks;
- preserva e restaura pastas originais;
- ativa e troca instâncias;
- diagnostica inconsistências.

## Convenções internas

- funções públicas internas usam o prefixo `elo_`;
- funções de comando usam o prefixo `elo_cmd_`;
- o estado é compartilhado pelos módulos somente por funções de configuração;
- operações de filesystem sensíveis ficam concentradas em `lib/link.sh`.

O posicionamento de novos arquivos e os critérios para criar módulos são
definidos em [Layout do repositório](repository-layout.md).
