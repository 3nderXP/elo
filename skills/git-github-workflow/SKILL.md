---
name: git-github-workflow
description: Especialização obrigatória em Git e GitHub para inspecionar histórico, revisar diffs, preparar commits, trabalhar com branches e remotes, criar tags semânticas, publicar releases ou orientar pull requests no projeto Elo. Use em qualquer tarefa que envolva git status, diff, add, commit, branch, merge, rebase, remote, push, tag, GitHub Release, PR ou automação de release.
---

# Git and GitHub Workflow

Atuar como especialista em Git/GitHub, preservando histórico, mudanças locais
e limites de autorização.

## Preparação obrigatória

Antes de qualquer operação Git:

1. Ler [Segurança e modelo Git](references/git-safety.md).
2. Ler [Fluxo GitHub](references/github.md) quando houver remote, push ou PR.
3. Ler [Versionamento e releases](references/releases.md) quando houver tag,
   versão, instalador ou GitHub Release.
4. Ler `specs/release-management.md` para aplicar a política do Elo.
5. Inspecionar `git status --short --branch` e o diff relevante.

## Competência esperada

Compreender e distinguir:

- working tree, index, `HEAD`, branches e refs;
- mudanças rastreadas, não rastreadas e ignoradas;
- commit, merge, rebase, cherry-pick e revert;
- branch local, upstream e remote-tracking branch;
- tag anotada, tag leve e GitHub Release;
- push normal, force push e `--force-with-lease`;
- SemVer e impacto de compatibilidade.

Não executar uma operação apenas por reconhecer o comando. Avaliar efeito no
histórico, no remote e nas mudanças não relacionadas.

## Regras inegociáveis

- Preservar alterações do usuário que não pertencem à tarefa.
- Não usar `reset --hard`, checkout destrutivo ou limpeza sem autorização.
- Não fazer commit, push, tag, release ou PR sem solicitação correspondente.
- Não usar `git add .` sem antes conferir todo o working tree.
- Não reescrever histórico compartilhado por padrão.
- Não mover, recriar, converter ou reutilizar uma tag publicada.
- Não criar tag para cada commit ou push.
- Criar tags somente após o merge de uma versão publicável em `main`.
- Verificar testes e árvore limpa antes de uma tag de release.

## Fluxo mínimo

1. Inspecionar estado e histórico.
2. Delimitar arquivos pertencentes à mudança.
3. Validar o conteúdo staged antes do commit.
4. Usar mensagem Conventional Commits curta e precisa.
5. Confirmar branch, remote e upstream antes de publicar.
6. Para release, seguir integralmente `specs/release-management.md`.
7. Relatar commit, tag ou ação remota produzida.
