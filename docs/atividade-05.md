# Atividade 5 — A stack completa

**Disciplina:** DevOps na Prática
**Professor:** Prof. Dr. Rafael Serapilha Durelli
**Aluno:** Vinícius Habib Andrade
**Branch:** `atividade-05`

## 1. Ambiente de execução

A atividade foi desenvolvida em ambiente Linux, utilizando Docker e Docker Compose.

```text
Usuário Linux: vinicius-habib
Diretório do projeto: /home/vinicius-habib/ufla-devops-shop
Branch: atividade-05
```

A estrutura criada para a atividade inclui:

```text
/home/vinicius-habib/ufla-devops-shop/
├── compose.yaml
├── .env
├── .env.example
├── nginx/
│   └── default.conf
└── docs/
    └── atividade-05.md
```

O arquivo `.env` foi utilizado localmente para armazenar as configurações do PostgreSQL. A senha foi definida por meio da variável `POSTGRES_PASSWORD` e não foi versionada no Git.

Exemplo da configuração utilizada:

```text
POSTGRES_DB=loja
POSTGRES_PASSWORD=<senha definida localmente no .env>
```

O arquivo `.env` permanece protegido pelo `.gitignore`.

## 2. Stack completa

A aplicação foi configurada utilizando quatro serviços independentes:

* `banco`: PostgreSQL 16 Alpine;
* `cache`: Redis 7 Alpine;
* `api`: imagem publicada no GitHub Container Registry;
* `nginx`: Nginx 1.27 Alpine como ponto de entrada da aplicação.

A API utiliza:

```text
DATABASE_URL=postgresql://postgres:<senha>@banco:5432/loja
REDIS_URL=redis://cache:6379/0
```

O PostgreSQL utiliza um volume Docker nomeado:

```text
dados_postgres:/var/lib/postgresql/data
```

O Nginx utiliza:

```text
./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
```

## 3. Estado final dos containers

Após executar:

```bash
docker compose up -d --wait
docker compose ps
```

foi obtido:

```text
NAME                       IMAGE                                     COMMAND                  SERVICE   CREATED          STATUS                   PORTS
ufla-devops-shop-api-1     ghcr.io/viniciushabib90/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       6 minutes ago    Up 6 minutes (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                        "docker-entrypoint.s…"   banco     6 minutes ago    Up 6 minutes (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                            "docker-entrypoint.…"   cache     6 minutes ago    Up 6 minutes (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                         "/docker-entrypoint.…"   nginx     41 seconds ago   Up 39 seconds            0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

A saída demonstra que os quatro serviços estão funcionando.

Também é possível observar que somente o Nginx publica uma porta no host:

```text
nginx → 0.0.0.0:80->80/tcp
```

A API, o PostgreSQL e o Redis possuem apenas suas portas internas:

```text
api    → 8000/tcp
banco  → 5432/tcp
cache  → 6379/tcp
```

## 4. Nginx como ponto de entrada

O Nginx foi configurado para encaminhar as requisições para o serviço `api` através do DNS interno do Docker:

```nginx
proxy_pass http://api:8000;
```

A configuração final também trata especificamente a requisição `HEAD` da página inicial:

```nginx
location = / {
    proxy_method GET;
    proxy_pass http://api:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

O teste solicitado no roteiro:

```bash
curl -I http://localhost
```

retornou:

```text
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 01 Oct 2026 18:23:09 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Thu, 24 Sep 2026 17:00:08 GMT
etag: "da04bc255824771a2f9a6643ecb0e65b"
```

Portanto, o acesso externo à aplicação ocorre corretamente através do Nginx.

## 5. PostgreSQL e Redis

O endpoint:

```bash
curl -s http://localhost/api/info
```

retornou:

```json
{
  "aplicacao": "ufla-devops-shop",
  "versao": "1.0.0",
  "banco": "postgresql",
  "cache": "redis",
  "instancia": "5c2cc1c2cc82"
}
```

Esse resultado demonstra que a API está executando em modo completo, utilizando PostgreSQL como banco de dados e Redis como cache.

## 6. Teste de persistência

Primeiramente foi criado um produto através da API:

```bash
curl -s -X POST http://localhost/api/produtos \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
```

Resultado:

```json
{
  "id": 13,
  "nome": "Prova de persistencia",
  "descricao": "",
  "preco": 9.9,
  "estoque": 1,
  "criado_em": "2026-10-01T18:16:34.145277+00:00"
}
```

Em seguida, a stack foi derrubada utilizando:

```bash
docker compose down
```

Resultado:

```text
✔ Container ufla-devops-shop-nginx-1 Removed
✔ Container ufla-devops-shop-api-1   Removed
✔ Container ufla-devops-shop-banco-1 Removed
✔ Container ufla-devops-shop-cache-1  Removed
✔ Network ufla-devops-shop_default   Removed
```

O volume nomeado do PostgreSQL não foi removido.

A stack foi então iniciada novamente:

```bash
docker compose up -d --wait
```

Resultado:

```text
✔ Network ufla-devops-shop_default   Created
✔ Container ufla-devops-shop-banco-1 Healthy
✔ Container ufla-devops-shop-cache-1 Healthy
✔ Container ufla-devops-shop-api-1   Healthy
✔ Container ufla-devops-shop-nginx-1 Healthy
```

Após a reinicialização, foi realizada a busca:

```bash
curl -s 'http://localhost/api/busca?q=persistencia'
```

Resultado:

```json
{
  "termo": "persistencia",
  "total": 1,
  "resultados": [
    {
      "id": 13,
      "nome": "Prova de persistencia",
      "descricao": "",
      "preco": 9.9,
      "estoque": 1,
      "criado_em": "2026-10-01T18:16:34.145277+00:00"
    }
  ]
}
```

O produto continuou disponível após `docker compose down` seguido de `docker compose up -d --wait`, comprovando a persistência dos dados no volume nomeado `dados_postgres`.

## 7. Volume do PostgreSQL

O serviço `banco` foi configurado com:

```yaml
volumes:
  - dados_postgres:/var/lib/postgresql/data
```

O volume utilizado pelo projeto é:

```text
ufla-devops-shop_dados_postgres
```

A utilização de um volume nomeado permite que os dados do PostgreSQL permaneçam armazenados mesmo quando os containers são removidos pelo comando:

```bash
docker compose down
```

O teste realizado na seção anterior confirmou essa persistência.

## 8. Healthchecks

O PostgreSQL possui o seguinte healthcheck:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -d ${POSTGRES_DB}"]
  interval: 5s
  timeout: 5s
  retries: 5
```

O Redis utiliza:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 5
```

A API depende dos dois serviços utilizando:

```yaml
depends_on:
  banco:
    condition: service_healthy
  cache:
    condition: service_healthy
```

### Por que `depends_on` sozinho não é suficiente?

O `depends_on` simples controla a ordem de inicialização dos containers, mas não garante que o serviço dependente já esteja efetivamente pronto para receber requisições. Um container pode estar iniciado enquanto o banco ainda está executando sua inicialização.

A condição `service_healthy` utiliza o resultado do healthcheck para que a API seja iniciada somente depois que PostgreSQL e Redis forem considerados saudáveis. Dessa forma, a ordem de inicialização considera não apenas o início dos containers, mas também a disponibilidade dos serviços necessários.

## 9. Imagem publicada no GHCR

A imagem da aplicação foi publicada no GitHub Container Registry com a versão SemVer:

```text
ghcr.io/viniciushabib90/ufla-shop:1.0.0
```

A imagem foi construída a partir da imagem local da Atividade 4 e publicada com:

```bash
docker tag ufla-shop:1.0 ghcr.io/viniciushabib90/ufla-shop:1.0.0
docker push ghcr.io/viniciushabib90/ufla-shop:1.0.0
```

A imagem utilizada no `compose.yaml` é exatamente:

```yaml
image: ghcr.io/viniciushabib90/ufla-shop:1.0.0
```

Não foi utilizada a tag `latest`.

O pacote foi configurado como público no GitHub Container Registry.

## 10. Variáveis de ambiente

O arquivo `.env.example` foi versionado para documentar as variáveis necessárias:

```text
POSTGRES_DB=loja
POSTGRES_PASSWORD=troque-esta-senha
```

O arquivo `.env` contém os valores utilizados localmente e não é versionado.

A senha do PostgreSQL é utilizada na configuração do banco e na construção da `DATABASE_URL`, evitando duplicação desnecessária da credencial em diferentes arquivos de configuração.

## 11. Configuração final do Compose

Os serviços configurados foram:

```text
banco
 └── PostgreSQL 16 Alpine
     └── volume dados_postgres

cache
 └── Redis 7 Alpine

api
 └── ghcr.io/viniciushabib90/ufla-shop:1.0.0
     ├── PostgreSQL → banco:5432
     └── Redis      → cache:6379

nginx
 └── nginx:1.27-alpine
     └── porta do host 80 → api:8000
```

Todos os serviços utilizam:

```yaml
restart: unless-stopped
```

A stack pode ser iniciada novamente com um único comando:

```bash
docker compose up -d --wait
```

e encerrada com:

```bash
docker compose down
```

Os dados do PostgreSQL permanecem preservados pelo volume nomeado.

## 12. Conclusão

A Atividade 5 foi implementada utilizando uma stack composta por API, PostgreSQL, Redis e Nginx, com os serviços executando em containers independentes. A API utiliza a imagem publicada no GHCR com a versão `1.0.0`, enquanto PostgreSQL e Redis são acessados através dos nomes dos serviços na rede interna do Docker.

Os testes realizados demonstraram o funcionamento da aplicação através do Nginx, a utilização efetiva de PostgreSQL e Redis, a saúde dos serviços e a persistência dos dados após a remoção e recriação dos containers. Somente o Nginx expõe uma porta no host, conforme especificado no enunciado.
