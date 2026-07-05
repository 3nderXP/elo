# Domínio Minecraft

## Diretório alvo

Launchers de Minecraft leem pastas convencionais dentro de `.minecraft`.
O MVP gerencia:

- `mods`;
- `resourcepacks`;
- `shaderpacks`;
- `config`.

O launcher não precisa conhecer o Elo. Ele continua acessando os mesmos paths,
que podem ser symlinks para a instância ativa.

## Instâncias

Cada instância vive fora do `.minecraft`, em
`$ELO_HOME/instances/<nome-instancia>/`. Seus arquivos pertencem à instância e não ao
backup original.

Versão e loader são apenas metadados no MVP. O Elo ainda não instala Minecraft,
Forge, Fabric, NeoForge, mods ou dependências.

## Estado original

Pastas reais encontradas no `.minecraft` antes da ativação não pertencem a
nenhuma instância. Elas representam o ambiente original do usuário e devem ser
restauradas pelo `reset`.

Trocar de instância não cria um novo original. O backup permanece vinculado ao
`.minecraft` configurado durante todo o ciclo de gerenciamento.
