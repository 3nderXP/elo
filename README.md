# Elo

Elo é uma CLI modular em Bash para gerenciar instâncias de Minecraft sem
depender de um launcher específico. Ela mantém cada instância em `~/.elo` e
aponta as pastas do `.minecraft` para a instância ativa por meio de symlinks.

## Estado atual

O MVP implementa:

- inicialização do diretório de dados;
- criação, listagem e remoção de instâncias;
- ativação e troca de instância;
- backup das pastas originais do `.minecraft`;
- reset com restauração do estado original;
- detecção de symlinks alterados ou externos.

O suporte inicial é direcionado a Linux e macOS com Bash.

## Executar em desenvolvimento

```bash
./elo.sh help
./elo.sh init --minecraft-path "$HOME/.minecraft"
./elo.sh new fabric-1_21 --version 1.21 --loader fabric
./elo.sh link fabric-1_21
./elo.sh status
./elo.sh reset
```

Por padrão, os dados ficam em `~/.elo`. A variável `ELO_HOME` permite usar
outro diretório, especialmente em testes.

## Estrutura

```text
elo.sh              parsing e despacho dos comandos
lib/utils.sh        mensagens, confirmação e validações
lib/config.sh       persistência de config.conf e state.conf
lib/instance.sh     ciclo de vida das instâncias
lib/link.sh         symlinks, backup, switch, reset e status
tests/test_elo.sh   testes de integração em diretórios temporários
```

`elo.sh` é intencionalmente pequeno. A lógica de filesystem que pode mover ou
remover dados fica concentrada em `lib/link.sh`.

## Testes

```bash
./tests/test_elo.sh
```

Os testes definem um `ELO_HOME` temporário e não acessam o `.minecraft` real.

## Documentação

- [Conhecimento obrigatório para LLMs](skills/elo-development/SKILL.md)
- [Especificações técnicas](specs/README.md)
- [Contexto inicial](initial-feat.md)
