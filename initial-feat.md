# Elo — Gerenciador de Instâncias/Modpacks de Minecraft (CLI)

## Contexto

O **Elo** é uma ferramenta de linha de comando (CLI) para gerenciar **instâncias de Minecraft** (mods, resourcepacks, shaderpacks, configs) de forma **totalmente desacoplada de qualquer launcher**. O projeto será implementado integralmente em **scripts shell (`.sh`) escritos em Bash**, tendo `elo.sh` como entrypoint da aplicação e arquivos `.sh` auxiliares para separar as responsabilidades.

Hoje, a maioria das ferramentas de gerenciamento de instâncias (MultiMC, Prism Launcher, CurseForge App, etc.) exige que o usuário use *aquele* launcher específico. O Elo resolve isso de outra forma: ele gerencia os arquivos em uma estrutura própria, fora da pasta `.minecraft`, e usa **links simbólicos (symlinks)** para "injetar" o conteúdo da instância ativa dentro do `.minecraft` real — não importa se o usuário usa o Minecraft Launcher oficial, TLauncher, Legacy Launcher, PrismLauncher, etc.

Ou seja: o launcher continua lendo `.minecraft/mods`, `.minecraft/resourcepacks`, etc. normalmente. O Elo só troca o que está por trás desses caminhos via symlink.

## Objetivo do MVP

Construir uma **CLI simples em Bash**, executada por meio do script `elo.sh` (sem TUI por enquanto), em que o usuário consiga:

1. Criar instâncias
2. Ativar (linkar) uma instância no `.minecraft`
3. Trocar de instância ativa
4. Resetar/desfazer o gerenciamento (voltar tudo ao estado original)
5. Listar instâncias e ver o status atual

Não é objetivo do MVP: baixar mods automaticamente, integrar com CurseForge/Modrinth API, ou gerenciar versões/loaders (Forge/Fabric) de forma automatizada. Isso fica para uma fase futura. No MVP, o usuário organiza os arquivos manualmente dentro da pasta da instância.

## Estrutura de diretórios

```bash
~/.elo/                              # diretório raiz do gerenciador (global, na home do usuário)
├── config.conf                      # configuração global
├── state.conf                       # estado atual de symlinks gerenciados
├── instances/
│   ├── <nome-instancia>/
│   │   ├── instance.conf            # metadados da instância
│   │   ├── mods/
│   │   ├── resourcepacks/
│   │   ├── shaderpacks/
│   │   └── config/
│   └── ...
└── backups/
    └── original/
        ├── mods.bak/                 # pasta original não gerenciada do .minecraft
        ├── resourcepacks.bak/        # preservada independentemente da instância
        └── ...
```

> Nota sobre o formato dos arquivos de configuração (`config.conf`, `instance.conf`, `state.conf`): ver seção **Stack do MVP: scripts `.sh` em Bash puro**, mais abaixo, que detalha o formato `KEY=VALUE` escolhido no lugar de TOML.

O backup representa o estado original do `.minecraft` antes de o Elo assumir o gerenciamento. Portanto, ele pertence ao diretório `.minecraft` configurado, e não a uma instância. Trocar entre instâncias nunca muda nem transfere esse backup.

## Pastas gerenciáveis

Inicialmente, as pastas que o Elo pode linkar são:

- `mods`
- `resourcepacks`
- `shaderpacks`
- `config`

Cada uma dessas pastas, dentro da instância, é opcional — se não existir dentro da instância, o Elo não tenta linkar aquela pasta específica.

## Fluxo de comandos (CLI)

### `elo init`

Inicializa o Elo pela primeira vez. Pergunta (ou recebe via flag) o caminho do `.minecraft` alvo e cria `~/.elo/config.conf`.

```bash
elo init --minecraft-path "/home/usuario/.minecraft"
```

### `elo new <nome-instancia>`

Cria uma nova instância vazia.

```bash
elo new skyblock-modpack --version 1.20.1 --loader forge
```

- Cria `~/.elo/instances/<nome-instancia>/` com `instance.conf` preenchido
- Cria subpastas vazias (`mods/`, `resourcepacks/`, `shaderpacks/`, `config/`)

### `elo link <nome-instancia>`

Ativa uma instância, criando os symlinks no `.minecraft`.

```bash
elo link skyblock-modpack
elo link skyblock-modpack --mode=backup    # move as pastas originais para backup (padrão)
elo link skyblock-modpack --mode=replace   # apaga as pastas originais (com confirmação explícita)
```

Comportamento:

1. Verifica se já existe uma instância linkada atualmente.
   - Se sim, pergunta se o usuário quer trocar (equivalente a rodar `elo switch`).
2. Para cada pasta gerenciável que existir na instância:
   - Verifica se o caminho correspondente no `.minecraft` já é um symlink gerenciado pelo Elo.
     - Se for, apenas remove o symlink antigo, sem mexer no backup original.
   - Se for uma pasta real (não symlink):
     - **Modo `backup` (padrão):** move a pasta para `~/.elo/backups/original/<pasta>.bak` e registra essa operação no `state.conf`.
     - **Modo `replace`:** remove a pasta original (pedir confirmação explícita no terminal, ex: digitar "sim" ou nome da pasta)
   - Cria o symlink: `.minecraft/<pasta> -> ~/.elo/instances/<nome-instancia>/<pasta>`
3. Atualiza `ACTIVE_INSTANCE` no `config.conf`.

### `elo switch <nome-instancia>`

Atalho para trocar de instância ativa sem passar pelo fluxo completo de confirmação de backup (já que a pasta atual do `.minecraft` já é um symlink gerenciado, não pasta real). Internamente reaproveita a lógica do `elo link`.

```bash
elo switch vanilla-1.20.1
```

### `elo reset`

Desfaz o gerenciamento do Elo: remove os symlinks atuais e restaura as pastas reais que existiam no `.minecraft` antes de serem substituídas pelo Elo. Essas pastas não pertencem a nenhuma instância e são recuperadas a partir do backup original.

```bash
elo reset
```

Comportamento:

1. Para cada pasta gerenciada atualmente linkada:
   - Remove o symlink em `.minecraft/<pasta>`
   - Se o `state.conf` registrar uma pasta original preservada e existir o backup em `~/.elo/backups/original/<pasta>.bak`, move a pasta de volta para `.minecraft/<pasta>`.
   - Se a pasta original não existia antes do Elo, apenas remove o symlink e mantém o caminho ausente.
   - Se a pasta foi removida com `--mode=replace`, avisa que não há original para restaurar.
2. Limpa `ACTIVE_INSTANCE` no `config.conf` e os registros `LINKED_*` e `ORIGINAL_*` no `state.conf`, encerrando o ciclo de gerenciamento atual.

O resultado esperado é o mesmo estado de diretórios que existia antes de o Elo começar a gerenciar o `.minecraft`, exceto pelos dados explicitamente removidos pelo usuário com `--mode=replace`.

### `elo list`

Lista todas as instâncias existentes, com nome, versão, loader e se está ativa.

```bash
elo list
```

Exemplo de saída:

```bash
NOME                  VERSÃO     LOADER   STATUS
skyblock-modpack      1.20.1     forge    ativa
vanilla-1.20.1        1.20.1     vanilla  -
teste-fabric          1.21.0     fabric   -
```

### `elo status`

Mostra o estado atual do `.minecraft` gerenciado: qual instância está ativa, quais pastas estão linkadas, e se existem backups pendentes de alguma operação anterior.

```bash
elo status
```

### `elo remove <nome-instancia>`

Remove uma instância (com confirmação). Se a instância estiver ativa no momento, pede para rodar `elo reset` antes, ou oferece fazer isso automaticamente.

```bash
elo remove teste-fabric
```

## Regras e cuidados importantes

- **Nunca remover dados do usuário sem confirmação explícita**, principalmente no modo `replace`.
- **O backup original é global para o `.minecraft` configurado, não por instância**: `link` e `switch` não podem sobrescrevê-lo. Somente um `reset` concluído com sucesso encerra esse ciclo de gerenciamento.
- **Symlinks devem ser identificáveis como "gerenciados pelo Elo"** — sugestão: guardar no `config.conf` ou em um arquivo de estado (`~/.elo/state.conf`) o mapeamento de quais caminhos do `.minecraft` estão atualmente linkados e para qual instância, ao invés de confiar apenas em checar se o caminho é um symlink (evita conflito com symlinks criados por outras ferramentas).
- **Detectar links "quebrados" ou órfãos**: se o usuário mexer manualmente nas pastas, o `elo status` deve conseguir detectar inconsistências (ex: symlink aponta pra instância que não existe mais) e avisar.
- **Multiplataforma (atenção especial ao Windows)**: criar symlinks no Windows exige privilégio de administrador ou "modo desenvolvedor" ativado. A CLI deve detectar erro de permissão e orientar o usuário claramente.
- **Idempotência**: rodar `elo link <nome-instancia>` para a instância que já está ativa não deve duplicar backups nem quebrar nada — deve apenas confirmar que já está tudo linkado.

## Stack do MVP: scripts `.sh` em Bash puro

Decisão: o MVP será construído inteiramente como **scripts `.sh` em Bash**. Não haverá implementação paralela em Python, Go, Rust ou outra linguagem no MVP. Motivos práticos:

- Zero dependência de runtime adicional — quem for rodar o `elo` só precisa do Bash, disponível por padrão na maioria dos ambientes Linux/macOS.
- O instalador via `curl | bash` (já planejado) fica natural: o script de instalação e o próprio programa são a mesma linguagem, sem precisar compilar binário nem empacotar interpretador.
- Symlinks são uma operação nativa e simples via `ln -s`.

**Limitação aceita conscientemente:** por ora, foco em **Linux/macOS**. Suporte a Windows fica fora do MVP (symlink no Windows via Bash puro — ex: Git Bash/WSL — teria comportamento inconsistente e exigiria tratamento à parte; deixar isso documentado como decisão consciente, não esquecimento).

### Ajuste no formato de configuração: TOML → formato simples chave=valor

TOML não tem parser nativo em Bash (exigiria dependência externa tipo `yq`/`toml-cli`, o que vai contra a ideia de "zero dependência"). O Elo usa arquivos `.conf` com um `KEY=VALUE` por linha e um parser pequeno em `lib/config.sh`, mantendo o formato legível sem adicionar dependências.

Os arquivos `.conf` **não devem ser executados com `source`**. Mesmo sendo arquivos locais, tratá-los como dados evita que uma edição manual malformada execute comandos arbitrários.

`~/.elo/config.conf` (exemplo):

```bash
MINECRAFT_PATH="/home/usuario/.minecraft"
ACTIVE_INSTANCE="skyblock-modpack"
MANAGED_FOLDERS="mods resourcepacks shaderpacks config"
```

`~/.elo/instances/<nome-instancia>/instance.conf` (exemplo):

```bash
INSTANCE_NAME="skyblock-modpack"
MINECRAFT_VERSION="1.20.1"
LOADER="forge"
CREATED_AT="2026-07-05T12:00:00Z"
NOTES=""
```

Os valores são lidos e atualizados pelas funções `elo_kv_get`, `elo_kv_set` e `elo_kv_unset`. O usuário ainda pode editar os arquivos manualmente, mas nenhuma linha é executada como código Bash.

Para o **estado de symlinks gerenciados** (`~/.elo/state.conf` — ver seção de regras e cuidados abaixo), o mesmo formato serve, ex:

```bash
LINKED_mods="skyblock-modpack"
LINKED_resourcepacks="skyblock-modpack"
ORIGINAL_mods="backed_up"
ORIGINAL_resourcepacks="backed_up"
ORIGINAL_shaderpacks="absent"
ORIGINAL_config="removed"
```

Os campos `ORIGINAL_*` registram o estado anterior ao gerenciamento:

- `backed_up`: havia uma pasta real, preservada em `~/.elo/backups/original/<pasta>.bak`;
- `absent`: o caminho não existia e não deve ser criado durante o `reset`;
- `removed`: havia uma pasta real, mas o usuário autorizou sua exclusão com `--mode=replace`, portanto não existe conteúdo original para restaurar.

### Organização do código

Mesmo em Bash, vale separar responsabilidades em arquivos, evitando um único script gigante:

```bash
elo/
├── elo.sh                  # entrypoint principal — faz o parsing dos comandos e chama as funções
├── lib/
│   ├── config.sh           # ler/escrever config.conf e instance.conf
│   ├── instance.sh         # criar/listar/remover instâncias
│   ├── link.sh             # lógica de link/switch/reset (symlinks + backup)
│   └── utils.sh            # funções auxiliares (confirmação, cores no terminal, checagem de erro)
├── install.sh              # script de instalação via curl (fase futura)
└── README.md
```

`elo.sh` faz `source` dos arquivos de `lib/` e despacha pro comando certo (`case "$1" in init) ...; new) ...; link) ...; esac`).

### Cuidados específicos de Bash a ter em mente

- Sempre usar `set -euo pipefail` no início dos scripts para falhar rápido em erro, variável não definida, ou erro em pipe.
- Evitar `eval` ao processar input do usuário (ex: nome de instância) — sanitizar nomes de instância (permitir só `[a-zA-Z0-9_-]`) antes de usar em paths.
- Testar existência de symlink com `[ -L "$caminho" ]`, e não confundir com `[ -e "$caminho" ]` (que falha se o link estiver quebrado).
- Mover pastas usar `mv`, criar link usar `ln -s "$origem" "$destino"` — sempre com paths absolutos, nunca relativos, pra evitar link quebrado se o usuário mover a pasta `~/.elo` no futuro.

## Escopo explícito do MVP (o que fazer primeiro)

1. `elo init`
2. `elo new`
3. `elo link` (com os dois modos: backup e replace)
4. `elo status`
5. `elo list`
6. `elo switch`
7. `elo reset`
8. `elo remove`

## Distribuição e instalação

O projeto será hospedado no **GitHub** e desenvolvido localmente em `~/dev-projects/elo` (essa é a pasta do *código-fonte* do projeto, não confundir com `~/.elo`, que é o diretório de dados/estado criado em runtime na máquina de quem instala a ferramenta).

Planejamento de instalação:

- **Fase de desenvolvimento (agora):** rodar o entrypoint localmente a partir de `~/dev-projects/elo`, usando `./elo.sh` ou `bash ./elo.sh`.
- **Fase de distribuição (futuro):** criar um script de instalação via `curl`, no estilo:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/<usuario>/elo/main/install.sh | bash
  ```

  Esse script deve:
  1. Baixar e instalar `elo.sh` e os módulos `.sh` do diretório `lib/`.
  2. Colocar o executável `elo` no `PATH` do usuário.
  3. **Não precisa criar `~/.elo` manualmente** — isso continua sendo responsabilidade do comando `elo init`, que já está no escopo do MVP. O script de instalação só cuida de deixar o comando `elo` disponível no terminal; a inicialização dos dados (`config.conf`, pastas, etc.) continua acontecendo no primeiro uso.

Importante ter isso em mente desde já no desenvolvimento, mesmo sem implementar o instalador ainda:

- Manter a lógica de "criação do ambiente" (`elo init`) **separada** da lógica de instalação dos scripts, para que o `install.sh` futuro seja só um instalador simples, sem lógica de negócio.
- Preservar a estrutura de módulos `.sh` na instalação e criar um comando `elo` que invoque o `elo.sh` instalado.
- Estruturar o repositório desde já pensando em um `install.sh` na raiz do projeto, mesmo que ele só seja escrito depois.

## Fora de escopo por enquanto (ideias futuras)

- Interface TUI
- Download automático de mods via Modrinth/CurseForge API
- Detecção automática de versão/loader instalado
- Perfis de configuração por launcher (ex: detectar automaticamente onde fica o `.minecraft` do TLauncher vs oficial)
- Exportar/importar instância como pacote `.zip` para compartilhar com outras pessoas
- Suporte a múltiplos `.minecraft` (múltiplos launchers instalados simultaneamente)
