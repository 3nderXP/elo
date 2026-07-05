# Testes do Elo

## Isolamento obrigatório

- Criar raiz temporária com `mktemp -d`.
- Definir `ELO_HOME` dentro dessa raiz.
- Criar um `.minecraft` descartável.
- Nunca depender de `HOME/.elo` ou `HOME/.minecraft`.
- Limpar apenas o diretório temporário criado pelo teste.

## Validações mínimas

Para mudanças no ciclo de filesystem, cobrir:

- original existente;
- path originalmente ausente;
- symlink externo;
- symlink quebrado ou divergente;
- troca entre duas instâncias;
- reset após ativação;
- paths contendo espaços;
- erro sem perda do backup.

## Execução

```bash
bash -n elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
```

Manter os testes determinísticos, sem rede e sem dependências externas.
