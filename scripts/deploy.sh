#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"

if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute este script com sudo."
    exit 1
fi

echo "==> Instalando dependências do sistema..."

apt-get update
apt-get install -y \
    python3 \
    python3-venv \
    python3-pip \
    postgresql \
    redis-server \
    nginx \
    openssl

echo "==> Garantindo serviços PostgreSQL e Redis..."

systemctl enable --now postgresql
systemctl enable --now redis-server

echo "==> Criando usuário do serviço..."

if ! id ufla-shop &>/dev/null; then
    useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin ufla-shop
fi

echo "==> Preparando diretório da aplicação..."

mkdir -p "$APP_DIR"

tar \
    --exclude='.git' \
    --exclude='.venv' \
    -C "$PROJECT_DIR" \
    -cf - . | tar -C "$APP_DIR" -xf -

echo "==> Criando ambiente de configuração..."

if [[ ! -f "$ENV_EXAMPLE" ]]; then
    cat > "$ENV_EXAMPLE" <<'EOF'
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
fi

if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "ATENÇÃO: configure o banco em $ENV_FILE antes de continuar."
fi

chmod 600 "$ENV_FILE"

echo "==> Criando ambiente virtual Python..."

python3 -m venv "$APP_DIR/.venv"

"$APP_DIR/.venv/bin/pip" install --upgrade pip

"$APP_DIR/.venv/bin/pip" install \
    -r "$APP_DIR/requirements.txt"

echo "==> Ajustando permissões..."

mkdir -p /var/backups/ufla-shop

chown -R ufla-shop:ufla-shop "$APP_DIR"

chown ufla-shop:ufla-shop /var/backups/ufla-shop

chmod 750 /var/backups/ufla-shop

echo "==> Instalando unidades systemd..."

install -m 0644 \
    "$APP_DIR/systemd/ufla-shop.service" \
    /etc/systemd/system/ufla-shop.service

install -m 0644 \
    "$APP_DIR/systemd/ufla-shop-backup.service" \
    /etc/systemd/system/ufla-shop-backup.service

install -m 0644 \
    "$APP_DIR/systemd/ufla-shop-backup.timer" \
    /etc/systemd/system/ufla-shop-backup.timer

systemctl daemon-reload

echo "==> Configurando certificado TLS..."

mkdir -p /etc/ssl/ufla-shop

if [[ ! -f /etc/ssl/ufla-shop/loja.pem ||
      ! -f /etc/ssl/ufla-shop/loja.key ]]; then

    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/ssl/ufla-shop/loja.key \
        -out /etc/ssl/ufla-shop/loja.pem \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

    chmod 600 /etc/ssl/ufla-shop/loja.key
    chmod 644 /etc/ssl/ufla-shop/loja.pem
fi

echo "==> Configurando Nginx..."

install -m 0644 \
    "$APP_DIR/nginx/ufla-shop.conf" \
    /etc/nginx/sites-available/ufla-shop.conf

rm -f /etc/nginx/sites-enabled/default

ln -sfn \
    /etc/nginx/sites-available/ufla-shop.conf \
    /etc/nginx/sites-enabled/ufla-shop.conf

nginx -t

systemctl enable nginx
systemctl restart nginx

echo "==> Ativando serviço da aplicação..."

systemctl enable ufla-shop
systemctl restart ufla-shop

echo "==> Ativando backup diário..."

systemctl enable --now ufla-shop-backup.timer

echo "==> Verificando aplicação..."

for tentativa in {1..10}; do
    if curl -fsS -o /dev/null \
        http://127.0.0.1:8000/ready; then

        echo "OK: aplicação respondeu /ready."
        exit 0
    fi

    echo "Aguardando aplicação... tentativa $tentativa/10"

    sleep 1
done

echo "ERRO: aplicação não respondeu /ready após 10 tentativas."

systemctl status ufla-shop --no-pager || true

exit 1
