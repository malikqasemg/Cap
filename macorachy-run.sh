#!/bin/zsh
# Start (or restart) self-hosted Cap (web + MySQL + MinIO + media server) for MacOrachy.
# Ports and secrets are picked once and kept in .env.macorachy so share links stay valid.
# URL -> /tmp/cap.url (MacOrachy reads it). Log -> /tmp/cap.log.
cd "$(dirname "$0")"
ENVF=.env.macorachy
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
in_use() { lsof -nP -iTCP:$1 -sTCP:LISTEN >/dev/null 2>&1; }
hex() { openssl rand -hex 32; }

if [[ ! -f $ENVF ]]; then
  CP=$(free_port); MP=$(free_port); MC=$(free_port)
  cat > $ENVF <<EOF
CAP_PORT=$CP
MINIO_PORT=$MP
MINIO_CONSOLE_PORT=$MC
CAP_URL=http://localhost:$CP
S3_PUBLIC_URL=http://localhost:$MP
MYSQL_PASSWORD=$(openssl rand -hex 12)
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 12)
MINIO_ROOT_USER=cap-admin
MINIO_ROOT_PASSWORD=$(openssl rand -hex 12)
DATABASE_ENCRYPTION_KEY=$(hex)
NEXTAUTH_SECRET=$(hex)
MEDIA_SERVER_WEBHOOK_SECRET=$(hex)
EOF
fi
source $ENVF
rm -f /tmp/cap.url
# Docker Desktop must be running.
if ! docker info >/dev/null 2>&1; then
  open -a Docker; for i in {1..60}; do docker info >/dev/null 2>&1 && break; sleep 2; done
fi
docker compose --env-file $ENVF -p cap up -d > /tmp/cap.log 2>&1 || { echo "Cap failed to start. Log: /tmp/cap.log"; exit 1; }
for i in {1..120}; do
  if curl -s -o /dev/null "http://127.0.0.1:$CAP_PORT/"; then
    echo "http://localhost:$CAP_PORT" > /tmp/cap.url
    echo "Cap on http://localhost:$CAP_PORT"
    exit 0
  fi
  sleep 1
done
echo "Cap did not answer in 2 min. Log: /tmp/cap.log  (docker compose -p cap logs cap-web)"; exit 1
