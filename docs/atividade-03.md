# Atividade 3 – Automatizar de verdade

## 1. Objetivo

Automatizar a execução da aplicação `ufla-devops-shop` como um serviço Linux, utilizando:

- script de deploy idempotente;
- serviço `systemd`;
- backup diário do PostgreSQL;
- Nginx como proxy reverso;
- HTTPS com certificado autoassinado;
- documentação e evidências dos testes realizados.

## 2. Como executar o deploy

Em uma máquina Linux com `systemd`, a partir da raiz do projeto:

```bash
chmod +x scripts/deploy.sh
sudo ./scripts/deploy.sh
```
## 3. Evidência do funcionamento da aplicação

Após a execução do deploy, o serviço foi iniciado pelo `systemd`.

A aplicação utiliza:

- PostgreSQL como banco de dados;
- Redis como cache;
- Uvicorn para executar a aplicação FastAPI;
- porta local `127.0.0.1:8000`.

O endpoint de prontidão retornou HTTP 200:

```text
HTTP/1.1 200 OK
{"status":"ok","banco":"ok","cache":"ok"}
```

O processo Uvicorn está sendo executado pelo usuário `ufla-shop`, e não pelo usuário `root`.
## 4. Serviço systemd

O serviço foi configurado em:

```text
/etc/systemd/system/ufla-shop.service
```

A unidade utiliza:

```text
User=ufla-shop
WorkingDirectory=/opt/ufla-shop
EnvironmentFile=/etc/ufla-shop.env
ExecStart=/opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000
Restart=on-failure
```

O serviço foi habilitado para iniciar automaticamente com o sistema.

Foi realizado um teste de reinicialização forçada do processo Uvicorn utilizando `sudo kill -9`. O `systemd` detectou a falha e iniciou automaticamente uma nova instância do serviço.

Evidência registrada no journal:

```text
Scheduled restart job, restart counter is at 1.
Started ufla-shop.service
```

Após o reinício automático, o serviço permaneceu ativo e o endpoint `/ready` voltou a responder HTTP 200.
## 5. Nginx e HTTPS

O Nginx foi configurado como proxy reverso da aplicação.

A configuração utiliza:

- HTTP na porta 80 com redirecionamento para HTTPS;
- HTTPS na porta 443;
- certificado autoassinado gerado com OpenSSL;
- proxy para `http://127.0.0.1:8000`;
- cabeçalhos `X-Real-IP`, `X-Forwarded-For` e `X-Forwarded-Proto`.

Arquivo de configuração:

```text
/etc/nginx/sites-available/ufla-shop.conf
```

Teste HTTPS:

```text
curl -k -i https://localhost/ready
HTTP/1.1 200 OK
```

Teste HTTP:

```text
curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Location: https://localhost/
```

A aplicação permanece disponível diretamente apenas em `127.0.0.1:8000`, enquanto o acesso externo é realizado pelo Nginx.
## 6. Backup PostgreSQL

O backup do banco PostgreSQL é realizado pelo script:

```text
/opt/ufla-shop/scripts/backup.sh
```

O script:

- utiliza `pg_dump` para gerar o backup do banco `loja`;
- compacta o resultado em formato `.sql.gz`;
- utiliza data e hora no nome do arquivo;
- mantém somente os 7 backups mais recentes;
- registra no `journal` o arquivo gerado e seu tamanho;
- utiliza `set -euo pipefail` para detectar falhas.

Os backups são armazenados em:

```text
/var/backups/ufla-shop/
```

Foram executadas três operações de backup, gerando os arquivos:

```text
loja-2026-09-24-1535.sql.gz
loja-2026-09-24-1547.sql.gz
loja-2026-09-24-1550.sql.gz
```

Exemplo de registro no journal:

```text
arquivo gerado: /var/backups/ufla-shop/loja-2026-09-24-1535.sql.gz tamanho: 4.0K
```


Resultado de `ls -la /var/backups/ufla-shop` após as três execuções:

```text
total 20K
drwxr-x--- 2 ufla-shop ufla-shop 4.0K Sep 24 15:50 .
drwxr-xr-x 3 root root 4.0K Sep 24 15:31 ..
-rw-r--r-- 1 ufla-shop ufla-shop 1.6K Sep 24 15:35 loja-2026-09-24-1535.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1.6K Sep 24 15:47 loja-2026-09-24-1547.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1.6K Sep 24 15:50 loja-2026-09-24-1550.sql.gz
```

## 7. Timer de backup e idempotência

O backup foi configurado para execução diária às 03:00 por meio do `systemd timer`.

Arquivos utilizados:

```text
/etc/systemd/system/ufla-shop-backup.service
/etc/systemd/system/ufla-shop-backup.timer
```

O timer utiliza:

```text
OnCalendar=*-*-* 03:00:00
Persistent=true
```

O timer foi habilitado e está ativo. A próxima execução programada foi verificada com `systemctl list-timers`.

A idempotência do deploy foi verificada executando o script duas vezes consecutivamente. As duas execuções terminaram com sucesso e o healthcheck confirmou o funcionamento da aplicação:

```text
Aguardando aplicação... tentativa 1/10
OK: aplicação respondeu /ready.
```

Na segunda execução consecutiva, o resultado também foi:

```text
Aguardando aplicação... tentativa 1/10
OK: aplicação respondeu /ready.
```

A execução repetida não criou um segundo usuário de serviço, não duplicou a configuração do Nginx e reutilizou o certificado TLS existente.
## 8. Checklist dos requisitos

- [x] Deploy automatizado e idempotente em `scripts/deploy.sh`.
- [x] Serviço da aplicação configurado no `systemd`.
- [x] Aplicação executando com o usuário não privilegiado `ufla-shop`.
- [x] Reinício automático do serviço após falha.
- [x] Backup PostgreSQL em `scripts/backup.sh`.
- [x] Retenção dos 7 backups mais recentes.
- [x] Backup diário configurado com `systemd timer`.
- [x] Nginx configurado como proxy reverso.
- [x] Redirecionamento HTTP para HTTPS.
- [x] Certificado TLS autoassinado.
- [x] Aplicação exposta localmente em `127.0.0.1:8000`.
- [x] Credenciais mantidas fora do repositório em `/etc/ufla-shop.env`.
- [x] Certificados TLS não versionados no Git.

## 9. Conclusão

A atividade foi implementada com automação de deploy, execução da aplicação como serviço `systemd`, backup periódico do PostgreSQL e proxy reverso Nginx com HTTPS. Os testes realizados confirmaram o funcionamento da aplicação, o reinício automático do serviço, a geração dos backups, o redirecionamento HTTP para HTTPS e a execução idempotente do deploy.
