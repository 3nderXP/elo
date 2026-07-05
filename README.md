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

## Instalação

Instale a versão atual diretamente do GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/3nderXP/elo/main/install.sh | bash
```

O instalador:

- baixa e valida todos os scripts antes de ativá-los;
- instala o código em `~/.local/share/elo`;
- cria o comando `elo` em `~/.local/bin`;
- não usa `sudo` e não cria `~/.elo`.

Se `~/.local/bin` ainda não estiver no seu `PATH`, o instalador mostrará o
aviso e o diretório que precisa ser adicionado.

Depois da instalação:

```bash
elo init --minecraft-path "$HOME/.minecraft"
elo --help
```

## Executar em desenvolvimento

```bash
./elo.sh help
./elo.sh init --minecraft-path "$HOME/.minecraft"
./elo.sh new fabric-1_21 --version 1.21 --loader fabric
./elo.sh link fabric-1_21
./elo.sh status
./elo.sh reset
```

Para consultar campos obrigatórios, opções, valores padrão e riscos:

```bash
./elo.sh --help
./elo.sh help link
./elo.sh reset --help
```

Por padrão, os dados ficam em `~/.elo`. A variável `ELO_HOME` permite usar
outro diretório, especialmente em testes.

## Estrutura

```text
install.sh             instalação local ou via GitHub
elo.sh                 parsing e despacho dos comandos
lib/utils.sh           mensagens, confirmação e validações
lib/help.sh            ajuda geral e específica
lib/config.sh          persistência de config.conf e state.conf
lib/instance.sh        ciclo de vida das instâncias
lib/link.sh            symlinks, backup, switch, reset e status
tests/test_elo.sh      testes do gerenciamento
tests/test_install.sh  teste isolado do instalador
```

`elo.sh` é intencionalmente pequeno. A lógica de filesystem que pode mover ou
remover dados fica concentrada em `lib/link.sh`.

## Testes

```bash
./tests/test_elo.sh
./tests/test_install.sh
```

Os testes definem um `ELO_HOME` temporário e não acessam o `.minecraft` real.

## Documentação

- [Conhecimento obrigatório para LLMs](skills/elo-development/SKILL.md)
- [Especialização Git/GitHub](skills/git-github-workflow/SKILL.md)
- [Especificações técnicas](specs/README.md)
- [Contexto inicial](initial-feat.md)
