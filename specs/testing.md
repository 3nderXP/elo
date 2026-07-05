# Estratégia de testes

## Localização

Os testes de integração estão em:

```text
tests/test_elo.sh
tests/test_install.sh
```

## Isolamento

Cada execução:

- cria diretórios temporários;
- define um `ELO_HOME` próprio;
- utiliza um `.minecraft` descartável;
- nunca acessa os dados reais do usuário;
- remove o ambiente temporário ao finalizar.

## Cobertura atual

- criação e listagem de instâncias;
- ativação, troca e reset;
- preservação do backup original;
- modo `replace`;
- proteção de symlinks externos;
- remoção de instância ativa;
- caminhos contendo espaços.
- clareza da ajuda geral e específica;
- exigência de confirmação para alterações de estado.
- instalação local isolada e execução do comando instalado.

## Execução

```bash
./tests/test_elo.sh
./tests/test_install.sh
```

Os testes imprimem resultados no formato TAP simplificado e encerram com
status diferente de zero na primeira falha.
