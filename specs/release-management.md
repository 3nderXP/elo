# GitFlow, versionamento e releases

## Modelo de branches

O Elo adota um GitFlow simplificado:

```text
feature/* ─┐
fix/* ─────┴─ squash merge ─> develop
                                  │
                                  └─ PR de release ─> main ─> tag ─> Release
```

### `main`

- representa somente versões publicáveis;
- **DEVE** existir no GitHub;
- **NÃO DEVE** receber push direto;
- **DEVE** ser atualizada por PR de release;
- o PR `develop → main` **DEVE** usar merge commit normal;
- não é necessário manter uma branch local `main`;
- `origin/main` **PODE** ser usado localmente como referência após `fetch`.

### `develop`

- é a branch de integração;
- **DEVE** ser a base de `feature/*` e `fix/*`;
- **DEVE** receber mudanças por PR com squash merge;
- **NÃO DEVE** receber tags de release;
- **NÃO DEVE** receber push direto no fluxo normal.

### Branches temporárias

- `feature/<descricao>`: nova funcionalidade baseada em `origin/develop`;
- `fix/<descricao>`: correção destinada à próxima release, baseada em
  `origin/develop`;
- `release/vX.Y.Z`: opcional para estabilização, baseada em `develop`;
- `hotfix/<descricao>`: correção urgente baseada em `origin/main`.

Branches temporárias **DEVEM** ser removidas após integração. Seus commits
**NÃO DEVEM** receber tags de versão.

## Fluxo de feature e fix

1. atualizar referências com `git fetch`;
2. criar `feature/*` ou `fix/*` a partir de `origin/develop`;
3. fazer commits locais coerentes;
4. publicar somente a branch temporária;
5. abrir PR para `develop`;
6. exigir testes e revisão;
7. usar squash merge;
8. remover a branch;
9. não criar tag.

Uma tag criada antes do squash apontaria para commits que não fazem parte do
histórico final de `develop`. Isso é proibido.

## Fluxo de release

1. confirmar que `develop` está publicável;
2. escolher a versão SemVer;
3. atualizar metadados e documentação de versão, quando existirem;
4. abrir PR `develop → main`;
5. executar todas as validações;
6. usar merge commit normal;
7. criar a tag no commit resultante em `main`;
8. publicar a GitHub Release baseada nessa tag.

A tag **NÃO DEVE** ser criada antes do merge do PR de release.

## Versionamento

Usar tags no formato:

```text
vMAJOR.MINOR.PATCH
```

- `PATCH`: correção compatível;
- `MINOR`: funcionalidade compatível;
- `MAJOR`: mudança incompatível na CLI, comportamento ou dados.

Enquanto o projeto estiver em `0.x`, incompatibilidades **DEVEM** ser
destacadas nas notas da release.

Commits e pushes normais **NÃO DEVEM** receber tags automaticamente.

## Cenário A: tag anotada via Git

Este é o caminho preferencial quando se deseja uma tag Git anotada.
Não exige checkout local de `main`:

```bash
git fetch origin
git tag -a v0.1.0 origin/main -m "Elo v0.1.0"
git push origin v0.1.0
```

Antes do comando, deve-se confirmar que `origin/main` aponta para o merge
correto da release. Depois do push, a GitHub Release deve selecionar a tag
existente `v0.1.0`.

## Cenário B: tag criada pela interface do GitHub

O fluxo totalmente web também é aceito:

1. concluir o merge do PR `develop → main`;
2. abrir **Releases → Draft a new release**;
3. em **Choose a tag**, digitar `vMAJOR.MINOR.PATCH`;
4. selecionar **Create new tag**;
5. selecionar `main` como target;
6. confirmar o commit exato da release;
7. preencher ou gerar as notas;
8. publicar a Release.

Tags criadas por esse fluxo **PODEM** ser usadas mesmo sem garantia de tag
anotada. A associação correta entre versão e commit de `main` é o requisito
obrigatório.

Não criar uma segunda tag local com o mesmo nome para “converter” seu tipo.
Tags publicadas são imutáveis.

## Imutabilidade

- uma tag publicada **NÃO DEVE** ser movida, sobrescrita ou reutilizada;
- uma correção **DEVE** receber uma nova versão;
- uma GitHub Release **DEVE** apontar para exatamente uma tag;
- a tag **DEVE** apontar para um commit alcançável a partir de `main`;
- a mesma tag **NÃO DEVE** representar conteúdos diferentes entre remotes.

## Hotfix

Uma correção urgente de produção:

1. nasce em `hotfix/*` a partir de `origin/main`;
2. entra em `main` por PR;
3. gera uma nova versão `PATCH`;
4. recebe tag somente depois do merge;
5. deve ser reaplicada em `develop` por PR ou cherry-pick controlado.

Não deixar `develop` sem uma correção que já existe em `main`.

## Proteções no GitHub

### Ruleset de `develop`

- exigir PR;
- exigir checks;
- exigir resolução de conversas;
- exigir squash merge;
- bloquear force push e exclusão.

### Ruleset de `main`

- exigir PR;
- exigir checks;
- exigir resolução de conversas;
- exigir merge commit no PR de release;
- bloquear push direto, force push e exclusão.

### Ruleset de tags `v*`

- bloquear atualização e exclusão;
- permitir criação somente pelos responsáveis por release;
- não bloquear o mecanismo escolhido para criar uma nova tag válida.

Não habilitar histórico estritamente linear em `main`, pois o fluxo exige
merge commits de release.

## Pré-condições de release

Antes de tag ou Release:

1. confirmar o commit alvo;
2. garantir que não há mudança pendente destinada à release;
3. executar:

   ```bash
   bash -n install.sh elo.sh lib/*.sh tests/*.sh
   ./tests/test_elo.sh
   ./tests/test_install.sh
   ```

4. validar skills modificadas;
5. revisar as mudanças desde a tag anterior;
6. confirmar que README e specs estão atualizados;
7. verificar que a nova tag ainda não existe;
8. registrar incompatibilidades e instruções de upgrade.

## Instalação reproduzível

Uma release deve poder ser instalada pela própria tag:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/3nderXP/elo/v0.1.0/install.sh |
  bash -s -- --ref v0.1.0
```

Usar `main` instala a versão publicável mais recente presente nessa branch,
mas uma tag explícita é necessária para reprodução exata e rollback.
