# Segurança e invariantes

## Proteção de caminhos

- nomes de instâncias aceitam somente `[a-zA-Z0-9_-]`;
- nomes em `MANAGED_FOLDERS` seguem a mesma restrição;
- valores como `../` são rejeitados antes de compor caminhos;
- symlinks externos nunca são removidos automaticamente.

## Operações destrutivas

O modo padrão de ativação é `backup`.

O modo `replace`:

- requer confirmação explícita;
- aceita `--yes` para automação consciente;
- registra a pasta como `removed`;
- não promete restauração posterior.

A remoção de instância também exige confirmação. Uma instância ativa só pode
ser removida após `reset`.

## Persistência segura

- arquivos `.conf` são tratados como dados, não código Bash;
- atualizações de chave usam arquivo temporário e `mv`;
- backups existentes não são sobrescritos;
- erros de reset mantêm o estado necessário para nova tentativa.

## Invariantes

- `ACTIVE_INSTANCE` deve representar a instância dos links ativos;
- cada `LINKED_<pasta>` deve corresponder ao destino real do symlink;
- cada estado `backed_up` deve possuir seu `<pasta>.bak`;
- um caminho original restaurado não permanece registrado como backup;
- dados não reconhecidos como pertencentes ao Elo não são removidos.
