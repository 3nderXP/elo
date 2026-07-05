#!/usr/bin/env bash

elo_help_header() {
  cat <<'EOF'
Elo — gerenciador de instâncias de Minecraft

O Elo troca mods, resourcepacks, shaders e configurações usando symlinks,
sem depender do launcher utilizado.

Notação:
  <valor>  obrigatório
  [valor]  opcional
EOF
}

elo_help_general() {
  elo_help_header
  cat <<'EOF'

Uso:
  elo <comando> [opções]

Comandos:
  init      Configura o diretório .minecraft que será gerenciado
  new       Cria uma instância vazia
  link      Ativa uma instância e cria os symlinks
  switch    Troca a instância ativa
  reset     Remove os symlinks e restaura as pastas originais
  list      Lista as instâncias existentes
  status    Diagnostica o estado atual do gerenciamento
  remove    Remove permanentemente uma instância
  help      Mostra esta ajuda ou a ajuda de um comando

Primeiros passos:
  elo init --minecraft-path "$HOME/.minecraft"
  elo new fabric-1_21 --version 1.21 --loader fabric
  elo link fabric-1_21
  elo status
  elo reset

Ajuda detalhada:
  elo help <comando>
  elo <comando> --help

Segurança:
  O modo padrão de link preserva as pastas originais em backup.
  Operações destrutivas ou que alteram o estado pedem confirmação.
  Use --yes apenas quando quiser confirmar de forma não interativa.
EOF
}

elo_help_init() {
  cat <<'EOF'
Uso:
  elo init --minecraft-path <caminho>

Inicializa o Elo e escolhe o diretório Minecraft que será gerenciado.
Nenhum arquivo do Minecraft é movido durante este comando.

Campos obrigatórios:
  --minecraft-path <caminho>
      Diretório .minecraft existente. Caminhos com espaços são aceitos.

Exemplo:
  elo init --minecraft-path "$HOME/.minecraft"
EOF
}

elo_help_new() {
  cat <<'EOF'
Uso:
  elo new <nome-instancia> [--version <versão>] [--loader <loader>]

Cria uma instância com as pastas mods, resourcepacks, shaderpacks e config.

Campos obrigatórios:
  <nome-instancia>
      Identificador único. Aceita letras, números, "_" e "-".

Campos opcionais:
  --version <versão>
      Versão informativa do Minecraft. Padrão: desconhecida.
  --loader <loader>
      Loader informativo, como fabric, forge ou neoforge. Padrão: vanilla.

Exemplo:
  elo new fabric-1_21 --version 1.21 --loader fabric
EOF
}

elo_help_link() {
  cat <<'EOF'
Uso:
  elo link <nome-instancia> [--mode <modo>] [--yes]

Ativa uma instância e aponta as pastas do .minecraft para ela.

Campos obrigatórios:
  <nome-instancia>
      Nome de uma instância existente.

Campos opcionais:
  --mode <modo>
      backup   Preserva as pastas reais antes de criar os links. Padrão.
      replace  Remove as pastas reais após confirmação. Não é reversível.
  --yes
      Confirma todas as perguntas. Indicado somente para automação consciente.

Exemplos:
  elo link fabric-1_21
  elo link teste-limpo --mode replace
EOF
}

elo_help_switch() {
  cat <<'EOF'
Uso:
  elo switch <nome-instancia> [--yes]

Troca os symlinks da instância ativa para outra instância.
O backup original não é alterado.

Campos obrigatórios:
  <nome-instancia>
      Nome da instância que será ativada.

Campos opcionais:
  --yes
      Confirma a troca sem fazer uma pergunta interativa.

Exemplo:
  elo switch vanilla-1_21
EOF
}

elo_help_reset() {
  cat <<'EOF'
Uso:
  elo reset [--yes]

Desfaz o gerenciamento atual: remove os symlinks reconhecidos pelo Elo e
restaura as pastas reais preservadas no backup original.

Campos opcionais:
  --yes
      Confirma o reset sem fazer uma pergunta interativa.

Observação:
  Dados removidos anteriormente com --mode replace não podem ser restaurados.

Exemplo:
  elo reset
EOF
}

elo_help_list() {
  cat <<'EOF'
Uso:
  elo list

Lista nome, versão, loader e situação de todas as instâncias.
Este comando não possui campos nem altera arquivos.
EOF
}

elo_help_status() {
  cat <<'EOF'
Uso:
  elo status

Mostra a instância ativa e verifica cada symlink e backup gerenciado.
Retorna código 1 quando encontra links ausentes, quebrados ou divergentes.
Este comando não possui campos nem altera arquivos.
EOF
}

elo_help_remove() {
  cat <<'EOF'
Uso:
  elo remove <nome-instancia> [--reset] [--yes]

Remove permanentemente uma instância e todo o conteúdo armazenado nela.

Campos obrigatórios:
  <nome-instancia>
      Nome da instância que será removida.

Campos opcionais:
  --reset
      Se a instância estiver ativa, restaura o .minecraft antes da remoção.
  --yes
      Confirma o reset e a remoção sem perguntas interativas.

Exemplo:
  elo remove teste-antigo
  elo remove instancia-ativa --reset
EOF
}

elo_help_help() {
  cat <<'EOF'
Uso:
  elo help [comando]

Sem argumento, mostra a visão geral. Com um comando, mostra campos,
comportamento, valores padrão e exemplos específicos.

Exemplo:
  elo help link
EOF
}

elo_help_command() {
  local command="${1:-}"

  case "$command" in
    "" | --help | -h) elo_help_general ;;
    init) elo_help_init ;;
    new) elo_help_new ;;
    link) elo_help_link ;;
    switch) elo_help_switch ;;
    reset) elo_help_reset ;;
    list) elo_help_list ;;
    status) elo_help_status ;;
    remove) elo_help_remove ;;
    help) elo_help_help ;;
    *)
      elo_error "Não existe ajuda para o comando: $command"
      elo_help_general >&2
      return 2
      ;;
  esac
}
