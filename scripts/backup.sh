#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
TIMESTAMP="$(date '+%Y-%m-%d-%H%M')"
BACKUP_FILE="$BACKUP_DIR/loja-$TIMESTAMP.sql.gz"

if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "ERRO: DATABASE_URL não está definida."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "==> Gerando backup PostgreSQL..."
pg_dump "$DATABASE_URL" | gzip > "$BACKUP_FILE"

echo "==> Backup criado: $BACKUP_FILE"

echo "==> Mantendo somente os 7 backups mais recentes..."

mapfile -t BACKUPS < <(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'loja-*.sql.gz' \
        -printf '%T@ %p\n' |
    sort -nr |
    cut -d' ' -f2-
)

if (( ${#BACKUPS[@]} > 7 )); then
    rm -f "${BACKUPS[@]:7}"
fi

SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"

logger -t backup "arquivo gerado: $BACKUP_FILE tamanho: $SIZE"

echo "==> Backup concluído: $BACKUP_FILE ($SIZE)"
