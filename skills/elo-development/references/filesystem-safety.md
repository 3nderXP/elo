# Segurança de filesystem

## Propriedade de symlinks

Considerar um link pertencente ao Elo somente quando:

1. existe `LINKED_<pasta>` em `state.conf`;
2. o path no `.minecraft` é um symlink;
3. o destino é exatamente a pasta esperada da instância registrada.

Recusar remoção quando qualquer condição divergir.

## Backup

- Guardar originais em `$ELO_HOME/backups/original/<pasta>.bak`.
- Manter no máximo um original por pasta.
- Falhar se o destino do backup já existir.
- Não associar backup ao nome da instância.
- Restaurar com `mv`, nunca por cópia seguida de exclusão.

## Estados

- `backed_up`: existe original preservado.
- `absent`: o path não existia originalmente.
- `removed`: exclusão foi autorizada com `replace`.

Não limpar o estado necessário à recuperação antes de concluir a operação
correspondente.

## Operações destrutivas

- Usar `backup` por padrão.
- Exigir confirmação explícita para `replace` e remoção de instância.
- Não seguir symlinks ao remover.
- Não tentar reparar automaticamente um path externo ou divergente.
- Em erro, preservar o máximo de evidência e dados para nova tentativa.
