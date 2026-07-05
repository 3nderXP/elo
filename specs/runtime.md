# Runtime e compatibilidade

## Requisitos

- Linguagem: Bash.
- Formato: scripts `.sh`.
- Entry point: `elo.sh`.
- Plataformas do MVP: Linux e macOS.
- Windows: fora do escopo atual.

## Dependências do sistema

O Elo utiliza ferramentas normalmente presentes no sistema:

- `mv`;
- `rm`;
- `ln`;
- `readlink`;
- `mktemp`;
- `date`.

Não há runtime adicional, compilação ou gerenciador de pacotes obrigatório.
O instalador remoto também requer `curl`.

## Política de compatibilidade

Os scripts usam `set -euo pipefail`. A implementação evita recursos exclusivos
do Bash 4, como variáveis por referência e arrays associativos, para manter
compatibilidade com versões antigas fornecidas pelo macOS.
