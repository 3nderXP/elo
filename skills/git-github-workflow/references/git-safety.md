# Segurança e modelo Git

## Modelo mental

- Working tree: conteúdo atual dos arquivos.
- Index: snapshot preparado para o próximo commit.
- `HEAD`: commit atualmente selecionado.
- Branch: ref móvel que avança com novos commits.
- Tag: ref de versão que deve permanecer imutável depois de publicada.

Inspecionar cada camada separadamente antes de alterá-la.

## Diagnóstico

Usar conforme necessário:

```bash
git status --short --branch
git diff
git diff --cached
git log --oneline --decorate -n 10
git remote -v
git branch -vv
```

## Staging e commits

- Adicionar somente arquivos pertencentes à tarefa.
- Conferir `git diff --cached --check` e `git diff --cached`.
- Não incorporar mudanças preexistentes sem intenção explícita.
- Usar Conventional Commits: `tipo(escopo): ação`.
- Preferir commit único por unidade lógica, não por arquivo.

## Histórico

- Preferir `revert` para desfazer mudança já compartilhada.
- Usar rebase apenas quando o efeito sobre commits locais for compreendido.
- Nunca presumir autorização para force push.
- Se force push for indispensável e autorizado, preferir
  `--force-with-lease`.
- Não apagar refs, reflog ou arquivos não rastreados para “limpar” o projeto
  sem autorização explícita.
