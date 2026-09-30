# Atividade 4 — Containerizar a aplicação

## 1. Tamanho da imagem

Foi criada inicialmente uma versão funcional da imagem utilizando
`python:3.12-slim`. Depois, a imagem foi otimizada utilizando
`python:3.12-alpine` como base da imagem final.

A comparação das duas versões foi realizada com `docker images`:

| Versão | Imagem base | DISK USAGE | CONTENT SIZE |
|---|---|---:|---:|
| Primeira versão funcional | `python:3.12-slim` | 236 MB | 56 MB |
| Versão final otimizada | `python:3.12-alpine` | 130 MB | 30,1 MB |
| Redução | — | 106 MB | 25,9 MB |

Considerando o `DISK USAGE` apresentado por `docker images`, a versão final
teve uma redução de 106 MB, aproximadamente 44,9% em relação à primeira
versão funcional.

A verificação específica do requisito de tamanho foi realizada com:

    docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si

Resultado:

    31M

Portanto, a imagem final está abaixo do limite de 150 MB estabelecido pela
atividade.

## 2. O que foi alterado e otimizações realizadas

O `Dockerfile` utiliza uma estratégia de construção multi-stage.

Na primeira etapa, denominada `builder`, as dependências presentes em
`requirements.txt` são instaladas em `/install`.

Na segunda etapa, é utilizada uma imagem limpa `python:3.12-alpine`.
Somente as dependências instaladas na etapa anterior, o código da aplicação
e os arquivos estáticos são copiados para a imagem final.

A principal otimização realizada foi a substituição da base
`python:3.12-slim` pela base `python:3.12-alpine`.

A primeira versão funcional apresentou 236 MB de `DISK USAGE`, enquanto a
versão final apresentou 130 MB, representando uma redução de 106 MB.

O `docker history` da imagem final também permitiu identificar o peso das
principais camadas. A camada das dependências possui aproximadamente
43,9 MB, o código da aplicação aproximadamente 115 kB e os arquivos
estáticos aproximadamente 24,6 kB.

Além da redução da imagem base, o uso de `pip install --no-cache-dir`
evita a inclusão do cache do pip na imagem.

## 3. .dockerignore

Foi criado o arquivo `.dockerignore` para evitar o envio de arquivos
desnecessários para o contexto de construção da imagem.

Foram incluídos no `.dockerignore`:

    .git
    .venv
    __pycache__
    tests
    *.db
    .env
    .pytest_cache
    .coverage
    *.pyc

A imagem foi verificada com:

    docker run --rm ufla-shop:1.0 sh -c 'find /app -maxdepth 2 -type f | sort'

O resultado foi:

    /app/app/__init__.py
    /app/app/__main__.py
    /app/app/banco.py
    /app/app/cache.py
    /app/app/config.py
    /app/app/principal.py
    /app/static/app.js
    /app/static/estilo.css
    /app/static/index.html

Não foram encontrados `.git`, `.venv`, `tests`, `.env` ou arquivos
`*.db` na aplicação presente na imagem.

## 4. Execução como usuário não-root

Foi criado um usuário específico para executar a aplicação:

    USER app

O usuário possui UID 10001.

A verificação foi realizada com:

    docker run --rm ufla-shop:1.0 id -u

Resultado:

    10001

Também foi verificada a configuração da imagem:

    docker inspect --format '{{.Config.User}}' ufla-shop:1.0

Resultado:

    app

Portanto, a aplicação é executada como usuário não-root.

## 5. Execução da aplicação

O container foi iniciado com:

    docker run -d --name loja -p 8000:8000 ufla-shop:1.0

A aplicação respondeu corretamente ao endpoint de saúde:

    curl -i http://localhost:8000/health

Resultado:

    HTTP/1.1 200 OK

Também foi testado o endpoint:

    curl -s http://localhost:8000/api/produtos

O endpoint retornou o catálogo da aplicação contendo os 12 produtos
iniciais.

## 6. HEALTHCHECK

O `Dockerfile` utiliza um `HEALTHCHECK` que consulta a rota `/health`
utilizando a biblioteca `urllib` da biblioteca padrão do Python.

A configuração utilizada foi:

    HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
        CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"

Após a inicialização do container, o status foi verificado com:

    docker inspect --format '{{.State.Health.Status}}' loja

Resultado:

    healthy

O `/health` é utilizado porque é a rota de liveness da aplicação e
verifica somente se o processo está vivo, sem depender do banco de dados
ou do cache.

O `/ready` é uma rota de readiness e verifica banco e cache. Por isso,
não é adequado para o HEALTHCHECK desta etapa, em que a aplicação roda
autonomamente com SQLite e cache em memória.

## 7. Comando de inicialização e encerramento

O comando de inicialização foi definido no formato exec:

    CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]

Dessa forma, o Uvicorn é o processo principal do container e recebe
corretamente o sinal `SIGTERM`.

O tempo de encerramento foi medido com:

    time docker stop loja

Resultado:

    real    0m0,439s
    user    0m0,011s
    sys     0m0,013s

O tempo real de encerramento foi de aproximadamente 0,44 segundo, abaixo
do limite de 2 segundos estabelecido pela atividade.

## 8. Conclusão

A imagem final foi construída utilizando multi-stage build e
`python:3.12-alpine`, ficando abaixo do limite de 150 MB.

A aplicação foi configurada para executar como usuário não-root, possui
`HEALTHCHECK`, utiliza comando em formato exec e apresenta encerramento
rápido.

Os endpoints `/health` e `/api/produtos` foram testados com sucesso, sendo
retornado o catálogo com os 12 produtos iniciais.
