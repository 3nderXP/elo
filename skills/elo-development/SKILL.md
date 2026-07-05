---
name: elo-development
description: Conhecimento obrigatório para desenvolver, revisar, testar ou documentar o projeto Elo com Bash, symlinks e dados de Minecraft. Use em qualquer tarefa que altere elo.sh, lib/*.sh, tests/*.sh, arquivos .conf, fluxo de backup/reset, estrutura do repositório ou especificações técnicas do Elo.
---

# Elo Development

Trabalhar no Elo como uma CLI Bash orientada à preservação dos dados do
usuário. Priorizar segurança de filesystem, modularidade e compatibilidade.

## Preparação obrigatória

Antes de alterar o projeto:

1. Ler `specs/README.md`.
2. Ler todas as referências desta skill:
   - [Bash e shell](references/bash.md);
   - [Domínio Minecraft](references/minecraft.md);
   - [Segurança de filesystem](references/filesystem-safety.md);
   - [Testes](references/testing.md).
3. Ler as specs específicas apontadas pelo índice para a área modificada.
4. Inspecionar o código existente antes de propor outra abstração.

## Fluxo de trabalho

1. Identificar o módulo proprietário da responsabilidade.
2. Confirmar invariantes de backup, estado e propriedade dos symlinks.
3. Fazer a menor alteração coerente com a arquitetura.
4. Adicionar ou atualizar testes isolados.
5. Executar `bash -n elo.sh lib/*.sh tests/*.sh`.
6. Executar `./tests/test_elo.sh`.
7. Executar `./tests/test_install.sh` quando instalação ou layout mudar.
8. Atualizar a spec afetada quando o contrato mudar.

## Regras inegociáveis

- Nunca remover, substituir ou mover dados não reconhecidos sem confirmação.
- Nunca confiar apenas em `-L`; validar o destino contra `state.conf`.
- Nunca sobrescrever um backup original.
- Nunca executar arquivos `.conf` com `source` ou `eval`.
- Nunca usar nomes fornecidos pelo usuário em paths sem validação.
- Não adicionar dependência de runtime sem mudar explicitamente a spec.
- Não misturar parsing da CLI com lógica de filesystem.
- Não acessar `~/.elo` ou `.minecraft` reais durante testes.
- Não declarar uma mudança pronta sem validar sintaxe e integração.

## Fonte de verdade

As specs definem como o software deve ser construído. Em conflito entre uma
referência desta skill, comentários e specs, seguir `specs/` e corrigir a
documentação desatualizada no mesmo trabalho.
