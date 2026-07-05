# Symlinks e backups

## Contrato de propriedade

Um symlink gerenciado deve atender simultaneamente a estas condições:

1. possuir `LINKED_<pasta>` no `state.conf`;
2. existir em `<minecraft-path>/<pasta>`;
3. apontar exatamente para
   `<elo-home>/instances/<nome-instancia>/<pasta>`.

Se qualquer condição falhar, o Elo considera o estado inconsistente e não
remove o caminho automaticamente.

## Contrato do backup

- existe no máximo um backup original por pasta gerenciável;
- o backup pertence ao `.minecraft` configurado, não a uma instância;
- `link` e `switch` nunca sobrescrevem um backup existente;
- `switch` preserva o backup durante o ciclo de gerenciamento;
- `reset` move o backup de volta ao local original;
- uma falha de restauração não descarta o backup afetado.

## Ciclo de ativação

1. validar a instância e o estado atual;
2. preservar ou remover a pasta real conforme o modo escolhido;
3. criar um symlink absoluto;
4. registrar `LINKED_<pasta>`;
5. atualizar `ACTIVE_INSTANCE`.

## Ciclo de reset

1. validar que cada link registrado pertence ao Elo;
2. remover o symlink;
3. restaurar o backup quando `ORIGINAL_<pasta>=backed_up`;
4. manter o caminho ausente para `absent` ou `removed`;
5. limpar o estado somente após cada operação correspondente.
