# Regras de desenvolvimento

## Princípios

- Preservação dos dados do usuário tem prioridade sobre conveniência.
- O comportamento padrão **DEVE** ser reversível.
- Cada responsabilidade **DEVE** possuir um único módulo proprietário.
- Configuração e estado **DEVEM** ser tratados como dados, nunca código.
- A implementação **DEVE** permanecer compreensível sem framework externo.

## É permitido

- adicionar funções pequenas ao módulo proprietário;
- criar novo módulo quando existir uma nova fronteira de responsabilidade;
- adicionar comandos mantendo parsing no entrypoint ou handler e regra de
  negócio no módulo correto;
- usar utilitários comuns do sistema documentados em `runtime.md`;
- estender o formato `.conf` com chaves compatíveis;
- melhorar mensagens sem quebrar códigos de saída documentados;
- adicionar testes isolados e helpers internos de teste.

## É proibido

- remover ou sobrescrever dados desconhecidos sem confirmação;
- remover symlink com base apenas em sua existência;
- sobrescrever `backups/original/<pasta>.bak`;
- usar `eval` ou `source` em `.conf`;
- aceitar travessia de diretórios em nomes;
- acessar `.minecraft` ou `~/.elo` reais em testes;
- colocar lógica de negócio em `elo.sh`;
- misturar código Python, Node.js, Go ou Rust ao MVP;
- adicionar dependência externa sem atualizar `runtime.md` e obter uma decisão
  explícita de arquitetura;
- declarar suporte ao Windows sem testes e spec próprios;
- alterar contrato da CLI silenciosamente.

## Processo de mudança

Antes de editar:

1. ler a skill `skills/elo-development/SKILL.md`;
2. ler o índice de specs e os contratos aplicáveis;
3. localizar o módulo proprietário;
4. identificar riscos para dados e compatibilidade.

Antes de executar Git ou GitHub, ler também
`skills/git-github-workflow/SKILL.md`. Tags e releases **DEVEM** seguir
`release-management.md`.

Durante a implementação:

1. preservar o comportamento existente não relacionado;
2. validar toda entrada usada em paths;
3. manter operações reversíveis até o ponto de confirmação;
4. atualizar estado somente em ordem recuperável;
5. adicionar teste que falharia sem a mudança.

Antes de concluir:

```bash
bash -n elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
./tests/test_install.sh
```

Também **DEVE** ser verificado:

- ausência de alterações acidentais;
- consistência entre código, skill e specs;
- manutenção das permissões executáveis;
- mensagens de erro acionáveis.

## Critério de pronto

Uma mudança está pronta somente quando:

- implementação pertence ao módulo correto;
- casos de sucesso e falha relevantes estão testados;
- nenhum teste toca dados reais;
- sintaxe Bash é válida;
- suíte de integração passa;
- contratos alterados estão documentados;
- limitações conhecidas novas foram registradas.
