# Contrato da CLI

## Sintaxe

```text
elo init --minecraft-path <caminho>
elo new <nome> [--version <versão>] [--loader <loader>]
elo link <nome> [--mode backup|replace] [--yes]
elo switch <nome>
elo reset
elo list
elo status
elo remove <nome> [--reset] [--yes]
elo help
```

## Saída

- mensagens informativas usam o prefixo `info:`;
- avisos usam `aviso:` em `stderr`;
- erros usam `erro:` em `stderr`;
- `list` e `status` produzem tabelas legíveis no terminal.

## Códigos de saída

- `0`: operação concluída ou estado consistente;
- `1`: falha operacional, validação recusada ou estado inconsistente;
- `2`: comando principal desconhecido.

`elo status` retorna `1` quando encontra links quebrados, ausentes ou
divergentes.

## Execução não interativa

Operações com confirmação falham quando `stdin` não é um terminal. A flag
`--yes` autoriza explicitamente a execução não interativa nos comandos que a
suportam.
