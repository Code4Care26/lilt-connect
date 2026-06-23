#!/usr/bin/env bash
#
# 02-crea-db.sh
# Crea PostgreSQL e Redis gestiti, entrambi con un endpoint sulla STESSA Private
# Network del cluster (IPAM: niente IP da gestire a mano). IDEMPOTENTE per nome.
#
# Password richieste da env (non si mettono in chiaro qui):
#   export PG_PASSWORD='...'  REDIS_PASSWORD='...'
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd python3
scw_account_banner

: "${PG_PASSWORD:?esporta PG_PASSWORD con la password admin di PostgreSQL}"
: "${REDIS_PASSWORD:?esporta REDIS_PASSWORD con la password di Redis}"

PN_ID="$(pn_id)"
[ -n "$PN_ID" ] || die "Private Network '$PN_NAME' non trovata. Lancia prima ./00-crea-rete.sh"

# ---- PostgreSQL --------------------------------------------------------
if [ -z "$(pg_id)" ]; then
  say "Creo PostgreSQL '$PG_NAME' ($PG_ENGINE, $PG_NODE) sulla Private Network ..."
  scw rdb instance create \
    region="$REGION" \
    name="$PG_NAME" \
    engine="$PG_ENGINE" \
    node-type="$PG_NODE" \
    user-name="$PG_USER" \
    password="$PG_PASSWORD" \
    init-endpoints.0.private-network.private-network-id="$PN_ID" \
    init-endpoints.0.private-network.enable-ipam=true \
    --wait
else
  say "PostgreSQL '$PG_NAME' già esistente: salto."
fi

# ---- Redis -------------------------------------------------------------
if [ -z "$(redis_id)" ]; then
  say "Creo Redis '$REDIS_NAME' (v$REDIS_VERSION, $REDIS_NODE, standalone) sulla Private Network ..."
  scw redis cluster create \
    zone="$ZONE" \
    name="$REDIS_NAME" \
    version="$REDIS_VERSION" \
    node-type="$REDIS_NODE" \
    cluster-size=1 \
    tls-enabled=true \
    user-name="$REDIS_USER" \
    password="$REDIS_PASSWORD" \
    endpoints.0.private-network.id="$PN_ID" \
    endpoints.0.private-network.enable-ipam=true
  say "Attendo che Redis sia pronto ..."
  scw redis cluster wait "$(redis_id)" zone="$ZONE" >/dev/null 2>&1 || true
else
  say "Redis '$REDIS_NAME' già esistente: salto."
fi

# ---- Endpoint privati (per i Secret) -----------------------------------
PG_EP="$(scw rdb instance get "$(pg_id)" region="$REGION" -o json | db_private_endpoint)" \
  || die "non riesco a leggere l'endpoint privato di PostgreSQL"
REDIS_EP="$(scw redis cluster get "$(redis_id)" zone="$ZONE" -o json | db_private_endpoint)" \
  || die "non riesco a leggere l'endpoint privato di Redis"

echo ""
say "Endpoint privati pronti. ./04-secrets.sh li rileggerà da solo, ma per riferimento:"
echo "    PostgreSQL : $PG_EP   (db: $PG_DBNAME, user: $PG_USER)"
echo "    Redis      : rediss://$REDIS_USER:***@$REDIS_EP"
echo ""
say "Fatto. Prossimo passo: ./03-build-push.sh"
