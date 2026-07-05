# Especificações de desenvolvimento do Elo

Este diretório é a fonte de verdade normativa para implementação e manutenção.
Os termos **DEVE**, **NÃO DEVE** e **PODE** indicam requisito, proibição e
opção, respectivamente.

## Leitura obrigatória para qualquer mudança

1. [Layout do repositório](repository-layout.md);
2. [Regras de desenvolvimento](development-rules.md);
3. [Arquitetura dos módulos](architecture.md);
4. [Segurança e invariantes](safety.md).

## Specs por área

- Alteração de ambiente ou dependência:
  [Runtime e compatibilidade](runtime.md).
- Alteração de configuração ou estado:
  [Persistência e modelo de dados](storage.md).
- Alteração de `link`, `switch` ou `reset`:
  [Symlinks e backups](linking.md).
- Alteração de comandos ou saída:
  [Contrato da CLI](cli-contract.md).
- Alteração ou adição de comportamento:
  [Estratégia de testes](testing.md).
- Planejamento técnico:
  [Limitações atuais](limitations.md).

Uma mudança que altera um contrato **DEVE** atualizar a spec correspondente no
mesmo conjunto de alterações.
