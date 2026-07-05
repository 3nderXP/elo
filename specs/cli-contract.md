# Contrato da CLI

## Sintaxe

```text
elo init --minecraft-path <caminho>
elo new <nome-instancia> [--version <versão>] [--loader <loader>]
elo link <nome-instancia> [--mode backup|replace] [--yes]
elo switch <nome-instancia> [--yes]
elo reset [--yes]
elo list
elo status
elo remove <nome-instancia> [--reset] [--yes]
elo help [comando]
elo <comando> --help
```

## Saída

- mensagens informativas usam o prefixo `info:`;
- avisos usam `aviso:` em `stderr`;
- erros usam `erro:` em `stderr`;
- `list` e `status` produzem tabelas legíveis no terminal.

## Ajuda

- a ajuda geral **DEVE** explicar a notação de campos obrigatórios e opcionais;
- cada comando **DEVE** possuir ajuda específica;
- a ajuda específica **DEVE** informar propósito, campos, valores padrão,
  riscos e pelo menos um exemplo quando houver argumentos;
- `elo help <comando>` e `elo <comando> --help` **DEVEM** produzir a mesma
  orientação.

## Códigos de saída

- `0`: operação concluída ou estado consistente;
- `1`: falha operacional, validação recusada ou estado inconsistente;
- `2`: comando principal desconhecido.

`elo status` retorna `1` quando encontra links quebrados, ausentes ou
divergentes.

## Execução não interativa

`link`, `switch`, `reset` e `remove` **DEVEM** confirmar alterações de estado
ou remoções. Em execução sem terminal, essas operações falham antes de alterar
arquivos. A flag `--yes` autoriza explicitamente a execução não interativa nos
comandos que a suportam.
