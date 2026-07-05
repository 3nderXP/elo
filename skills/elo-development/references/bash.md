# Bash e shell

## Compatibilidade

- Escrever scripts Bash `.sh`.
- Manter compatibilidade com Bash 3.2 quando possível.
- Não usar arrays associativos, `local -n`, `mapfile` ou expansões exclusivas
  de versões recentes sem alterar a spec de runtime.
- Usar `#!/usr/bin/env bash` em scripts executáveis.
- Habilitar `set -euo pipefail` no entrypoint e nos testes.

## Manipulação segura

- Citar expansões: `"$path"`, `"$name"` e `"${array[@]}"`.
- Separar opções e operandos quando o utilitário suportar `--`.
- Validar nomes antes de concatená-los a paths.
- Usar `[ -L "$path" ]` para detectar inclusive symlink quebrado.
- Não usar `eval`.
- Não executar configuração com `source`.
- Preferir `printf` a `echo` para dados e mensagens previsíveis.

## Organização

- Prefixar funções com `elo_`.
- Usar `elo_cmd_` apenas para handlers da CLI.
- Declarar variáveis de função com `local`.
- Retornar status diferente de zero em validações recusadas.
- Concentrar operações destrutivas no módulo proprietário.

## Comandos relevantes

- `ln -s`: criar symlinks absolutos.
- `readlink`: comparar o destino real com o destino registrado.
- `mv`: preservar e restaurar originais.
- `rm`: remover somente links reconhecidos ou dados confirmados.
- `mktemp`: criar arquivos temporários e ambientes de teste.
- `bash -n`: validar sintaxe antes dos testes.
