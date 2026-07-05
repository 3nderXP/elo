# Fluxo GitHub

## Remote e publicação

- Confirmar URL e nome do remote antes de push.
- Confirmar branch atual e upstream.
- Não inferir que o remote se chama `origin`.
- Não criar ou alterar recursos remotos sem solicitação.
- Depois do push, informar branch e commits publicados.

## Pull requests

Antes de abrir ou atualizar uma PR:

1. garantir que a branch contém somente mudanças relacionadas;
2. executar validações exigidas pelas specs;
3. revisar o diff contra a branch base;
4. resumir comportamento e riscos, não apenas arquivos;
5. não alegar que checks passaram sem verificar.

## Tags e GitHub Releases

Uma tag Git e uma GitHub Release não são a mesma coisa:

- a tag identifica um commit imutável;
- a GitHub Release adiciona título, notas e artefatos à tag.

É permitido selecionar uma tag existente ou criar uma nova tag pelo formulário
da Release. Nos dois casos, conferir que ela aponta para o commit de release em
`main`.

Não marcar todos os pushes. Commits comuns continuam em `main`; apenas versões
publicáveis recebem tag.
