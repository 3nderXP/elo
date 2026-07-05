# Persistência e modelo de dados

## Estrutura

```text
~/.elo/
├── config.conf
├── state.conf
├── instances/
│   └── <nome>/
│       ├── instance.conf
│       ├── mods/
│       ├── resourcepacks/
│       ├── shaderpacks/
│       └── config/
└── backups/
    └── original/
        └── <pasta>.bak/
```

A variável `ELO_HOME` pode substituir `~/.elo`.

## Formato

Os arquivos `.conf` armazenam um par `CHAVE=VALOR` por linha. Eles são
interpretados como dados por `elo_kv_get`, `elo_kv_set` e `elo_kv_unset`.
Nunca são executados com `source`.

Valores não podem conter quebras de linha.

## Configuração global

`config.conf`:

```text
MINECRAFT_PATH=/home/usuario/.minecraft
ACTIVE_INSTANCE=skyblock
MANAGED_FOLDERS=mods resourcepacks shaderpacks config
```

## Metadados da instância

`instances/<nome>/instance.conf`:

```text
INSTANCE_NAME=skyblock
MINECRAFT_VERSION=1.20.1
LOADER=forge
CREATED_AT=2026-07-05T12:00:00Z
NOTES=
```

## Estado operacional

`state.conf` pode conter dois campos por pasta:

```text
LINKED_mods=skyblock
ORIGINAL_mods=backed_up
```

`LINKED_<pasta>` identifica a instância esperada no symlink.

`ORIGINAL_<pasta>` aceita:

- `backed_up`: original preservado em `backups/original/<pasta>.bak`;
- `absent`: caminho inexistente antes do gerenciamento;
- `removed`: original excluído com autorização no modo `replace`.
