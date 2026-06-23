#!/usr/bin/env bash
#
# 04-secrets.sh
# Crea/aggiorna il Secret Kubernetes che alimenta i pod: connessione a Postgres
# e Redis (endpoint privati letti da Scaleway), secret SSE condiviso e master key
# Rails. IDEMPOTENTE (apply di un manifest renderizzato in memoria).
#
# Da env:  SSE_PUBLISH_SECRET, PG_PASSWORD, REDIS_PASSWORD
#          VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY (Web Push), VAPID_SUBJECT (opz.)
#          RAILS_MASTER_KEY (se assente, letto da backend/config/master.key)
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd python3; require_cmd kubectl

: "${SSE_PUBLISH_SECRET:?esporta SSE_PUBLISH_SECRET (lo stesso valore per rails e gosse)}"
: "${PG_PASSWORD:?esporta PG_PASSWORD}"
: "${REDIS_PASSWORD:?esporta REDIS_PASSWORD}"
# Web Push (VAPID). Keypair STABILE: generato UNA volta e conservato nel secret
# manager del team. Rigenerarlo invalida tutte le PushSubscription già salvate
# nei browser (la applicationServerKey è cotta in ognuna). Genera con:
#   cd backend && bundle exec ruby -e 'require "web-push"; k=WebPush.generate_key; \
#     puts "VAPID_PUBLIC_KEY=#{k.public_key}"; puts "VAPID_PRIVATE_KEY=#{k.private_key}"'
: "${VAPID_PUBLIC_KEY:?esporta VAPID_PUBLIC_KEY (keypair VAPID stabile — vedi commento sopra)}"
: "${VAPID_PRIVATE_KEY:?esporta VAPID_PRIVATE_KEY (keypair VAPID stabile — vedi commento sopra)}"
VAPID_SUBJECT="${VAPID_SUBJECT:-mailto:$ACME_EMAIL}"
RAILS_MASTER_KEY="${RAILS_MASTER_KEY:-$(cat "$ROOT_DIR/backend/config/master.key" 2>/dev/null || true)}"
: "${RAILS_MASTER_KEY:?RAILS_MASTER_KEY non impostata e backend/config/master.key assente}"

PG_ID="$(pg_id)";    [ -n "$PG_ID" ]    || die "PostgreSQL '$PG_NAME' non trovato. Lancia ./02-crea-db.sh"
REDIS_ID="$(redis_id)"; [ -n "$REDIS_ID" ] || die "Redis '$REDIS_NAME' non trovato. Lancia ./02-crea-db.sh"

PG_EP="$(scw rdb instance get "$PG_ID" region="$REGION" -o json | db_private_endpoint)" \
  || die "endpoint privato PostgreSQL non leggibile"
REDIS_EP="$(scw redis cluster get "$REDIS_ID" zone="$ZONE" -o json | db_private_endpoint)" \
  || die "endpoint privato Redis non leggibile"

PG_HOST="${PG_EP%%:*}"; PG_PORT="${PG_EP##*:}"
# rediss:// = TLS, come configurato in 02. go-redis lo gestisce (ParseURL).
REDIS_URL="rediss://${REDIS_USER}:${REDIS_PASSWORD}@${REDIS_EP}"

say "Creo/aggiorno il Secret '$SECRET_NAME' ..."
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=rails-master-key="$RAILS_MASTER_KEY" \
  --from-literal=sse-publish-secret="$SSE_PUBLISH_SECRET" \
  --from-literal=database-host="$PG_HOST" \
  --from-literal=database-port="$PG_PORT" \
  --from-literal=database-username="$PG_USER" \
  --from-literal=database-password="$PG_PASSWORD" \
  --from-literal=database-name="$PG_DBNAME" \
  --from-literal=redis-url="$REDIS_URL" \
  --from-literal=vapid-public-key="$VAPID_PUBLIC_KEY" \
  --from-literal=vapid-private-key="$VAPID_PRIVATE_KEY" \
  --from-literal=vapid-subject="$VAPID_SUBJECT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
say "Secret pronto (Postgres @ $PG_HOST:$PG_PORT, Redis @ $REDIS_EP)."
say "Fatto. Prossimo passo: ./05-deploy.sh"
