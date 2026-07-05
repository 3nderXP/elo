# Versionamento e releases

## SemVer

Usar tags `vMAJOR.MINOR.PATCH`:

- `PATCH`: correção compatível;
- `MINOR`: funcionalidade compatível;
- `MAJOR`: mudança incompatível.

Durante `0.x`, tratar mudanças incompatíveis com atenção explícita nas notas,
mesmo quando o incremento adotado for `MINOR`.

## Momento da tag

Não criar tag em `feature/*`, `fix/*`, `release/*` ou `develop`. Criar somente
depois que o PR de release entrar em `main`.

## Tag anotada via Git

Preferir este caminho quando tags anotadas forem requisito:

```bash
git fetch origin
git tag -a v0.1.0 origin/main -m "Elo v0.1.0"
git push origin v0.1.0
```

Antes de criar:

- confirmar versão e commit alvo;
- confirmar que `origin/main` aponta para o merge da release;
- executar testes;
- verificar que a tag ainda não existe local ou remotamente;
- confirmar que o commit está pronto para usuários.

## Tag pela interface do GitHub

Também é permitido criar a tag durante **Draft a new release**, escolhendo
`main` como target e conferindo o commit exato. Esse fluxo pode não produzir
uma tag anotada, mas é válido conforme a spec do Elo.

## Imutabilidade

Uma tag publicada não deve ser movida para outro commit. Corrigir uma release
com nova versão, normalmente incrementando `PATCH`.

## Instalador

Para reproduzir uma versão, instalar com uma ref explícita:

```bash
./install.sh --ref v0.1.0
```

O comando remoto pode buscar `install.sh` na mesma tag para manter bootstrap e
arquivos instalados na mesma versão.
