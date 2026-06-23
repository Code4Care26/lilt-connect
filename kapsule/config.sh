#!/usr/bin/env bash
#
# config.sh — configurazione + helper condivisi dagli script kapsule/.
# Ogni NN-*.sh fa:  . "$(dirname "$0")/config.sh"
# Ogni valore è sovrascrivibile da env, es.:  TAG=v2 ./03-build-push.sh
#
# NB: Scaleway non ha una region "Italia". fr-par (Parigi) è la GA più vicina;
#     la zona serve a Redis (zonale). Vedi README §1.
set -euo pipefail

# ---- Segreti di deploy da file locale (gitignored) --------------------
# Carica kapsule/.env se presente, così non devi ri-esportare i segreti a ogni
# shell (stesso pattern di run.sh per backend/.env). Il file è la FONTE DI
# VERITÀ per i segreti (PG/REDIS/SSE/VAPID); i knob di config qui sotto
# restano sovrascrivibili da env al volo. Template: kapsule/.env.example.
__KAPSULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$__KAPSULE_DIR/.env" ]; then
  set -a; . "$__KAPSULE_DIR/.env"; set +a
fi

# ---- Region / zona -----------------------------------------------------
REGION="${REGION:-fr-par}"
ZONE="${ZONE:-fr-par-1}"

# ---- Account Scaleway (profilo) ---------------------------------------
# Account su cui agiscono TUTTI gli script. Default: il profilo "hackathon"
# (crealo una volta con `scw -p hackathon init`). Va qui — non in 00 — perché
# ogni NN-*.sh è un processo a sé: solo config.sh, che tutti sorgentano, lo
# propaga a tutti. Sovrascrivibile al volo:  SCW_PROFILE=altro ./02-crea-db.sh
SCW_PROFILE="${SCW_PROFILE:-hackathon}"
export SCW_PROFILE
# In alternativa al profilo, le env SCW_ACCESS_KEY/SCW_SECRET_KEY/
# SCW_DEFAULT_ORGANIZATION_ID/SCW_DEFAULT_PROJECT_ID hanno priorità sul file.
# Gli script passano comunque region/zone ESPLICITi, quindi il default-region
# del profilo (anche it-mil) non li devia.

# ---- Private Network (VPC) --------------------------------------------
PN_NAME="${PN_NAME:-lilt-pn}"

# ---- Cluster Kapsule ---------------------------------------------------
CLUSTER_NAME="${CLUSTER_NAME:-lilt-cluster}"
K8S_VERSION="${K8S_VERSION:-1.32.4}"   # VERIFICA: scw k8s version list region=$REGION
NODE_TYPE="${NODE_TYPE:-DEV1-M}"
POOL_SIZE="${POOL_SIZE:-2}"
POOL_MIN="${POOL_MIN:-2}"
POOL_MAX="${POOL_MAX:-10}"

# ---- Container Registry ------------------------------------------------
# Namespace del registry (GLOBALMENTE UNIVOCO per region). Per questo hackathon
# è 'lilt-connect' sull'account hackathon. Sovrascrivibile: REGISTRY_NS=... ./03-...
REGISTRY_NS="${REGISTRY_NS:-lilt-connect}"
REGISTRY="rg.${REGION}.scw.cloud"
# Tag delle immagini: va passato SEMPRE esplicito agli script che lo usano
# (03/05/07/publish), come 1° argomento. Niente derivazione automatica dal git:
# era la causa del mismatch build/deploy (build a :0.0.1, deploy a :latest).
# Gli script che ne hanno bisogno impostano TAG da $1 PRIMA di sorgentare questo
# file, così le immagini qui sotto risultano con il tag giusto.
TAG="${TAG:-}"
BACKEND_IMAGE="${REGISTRY}/${REGISTRY_NS}/lilt-backend:${TAG}"
GOSSE_IMAGE="${REGISTRY}/${REGISTRY_NS}/lilt-gosse:${TAG}"
FRONTEND_IMAGE="${REGISTRY}/${REGISTRY_NS}/lilt-frontend:${TAG}"

# ---- PostgreSQL gestito ------------------------------------------------
PG_NAME="${PG_NAME:-lilt-pg}"
PG_ENGINE="${PG_ENGINE:-PostgreSQL-16}"  # VERIFICA: scw rdb engine list region=$REGION
PG_NODE="${PG_NODE:-DB-DEV-S}"           # VERIFICA: scw rdb node-type list region=$REGION
PG_USER="${PG_USER:-lilt}"
PG_DBNAME="${PG_DBNAME:-lilt_production}"

# ---- Redis gestito -----------------------------------------------------
REDIS_NAME="${REDIS_NAME:-lilt-redis}"
REDIS_VERSION="${REDIS_VERSION:-8.6.3}"  # VERIFICA: scw redis version list zone=$ZONE
REDIS_NODE="${REDIS_NODE:-RED1-micro}"   # VERIFICA: scw redis node-type list zone=$ZONE
REDIS_USER="${REDIS_USER:-lilt}"

# ---- Kubernetes --------------------------------------------------------
SECRET_NAME="${SECRET_NAME:-lilt-secrets}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-controller-v1.11.3}"

# ---- Dominio + HTTPS (cert-manager / Let's Encrypt) -------------------
APP_HOST="${APP_HOST:-connect.code4care-leanbit.eu}"   # hostname pubblico (A record → IP dell'Ingress)
ACME_EMAIL="${ACME_EMAIL:-admin@example.com}" # account ACME (avvisi scadenza cert) — imposta la tua email reale via env
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.20.2}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$HERE/k8s"
ROOT_DIR="$(cd "$HERE/.." && pwd)"

# ---- helper ------------------------------------------------------------
say()  { echo ">> $*"; }
die()  { echo "ERRORE: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando '$1' non trovato"; }

# Risolve un ID per nome esatto; stringa vuota se assente. (Stile hello-kapsule.)
pn_id() {
  scw vpc private-network list region="$REGION" -o json \
    | NAME="$PN_NAME" python3 -c \
      "import sys,json,os; n=os.environ['NAME']; m=[x['id'] for x in json.load(sys.stdin) if x['name']==n]; print(m[0] if m else '')"
}
cluster_id() {
  scw k8s cluster list region="$REGION" -o json \
    | NAME="$CLUSTER_NAME" python3 -c \
      "import sys,json,os; n=os.environ['NAME']; m=[c['id'] for c in json.load(sys.stdin) if c['name']==n]; print(m[0] if m else '')"
}
pg_id() {
  scw rdb instance list region="$REGION" -o json \
    | NAME="$PG_NAME" python3 -c \
      "import sys,json,os; n=os.environ['NAME']; m=[x['id'] for x in json.load(sys.stdin) if x['name']==n]; print(m[0] if m else '')"
}
redis_id() {
  scw redis cluster list zone="$ZONE" -o json \
    | NAME="$REDIS_NAME" python3 -c \
      "import sys,json,os; n=os.environ['NAME']; m=[x['id'] for x in json.load(sys.stdin) if x['name']==n]; print(m[0] if m else '')"
}

# Estrae "host:port" dall'endpoint su Private Network di un DB gestito (JSON su
# stdin). Difensivo sui nomi dei campi: se torna vuoto, ispeziona con
#   scw rdb instance get <id> -o json   /   scw redis cluster get <id> -o json
db_private_endpoint() {
  python3 -c '
import sys, json
d = json.load(sys.stdin)
eps = d.get("endpoints") or []
priv = [e for e in eps if (e.get("private_network") or e.get("private-network"))] or eps
if not priv:
    sys.exit("nessun endpoint")
e = priv[0]
ip = e.get("ip") or (e.get("ips") or [None])[0]
if isinstance(ip, dict):
    ip = ip.get("address") or ip.get("ip")
host = e.get("hostname") or (ip.split("/")[0] if ip else None)
port = e.get("port") or 0
if not host:
    sys.exit("host non trovato")
print(f"{host}:{port}")
'
}

# Stampa (su stderr, per non sporcare l'output catturabile) su QUALE account
# Scaleway si sta per agire. Lettura locale via env o config file, niente API.
scw_account_banner() {
  if [ -n "${SCW_ACCESS_KEY:-}" ]; then
    echo ">> Account Scaleway: via env (access-key ${SCW_ACCESS_KEY:0:6}…, org ${SCW_DEFAULT_ORGANIZATION_ID:-?}) — region=$REGION zone=$ZONE" >&2
    return 0
  fi
  command -v scw >/dev/null 2>&1 || return 0
  local prof org
  prof="$(scw config info 2>/dev/null | awk '/^ProfileName/{print $2}')"
  org="$(scw config info 2>/dev/null | awk '/default-organization-id/{print $2}')"
  echo ">> Account Scaleway: profilo='${prof:-?}' org='${org:-?}' — region=$REGION zone=$ZONE" >&2
  [ -n "${SCW_PROFILE:-}" ] || echo "   (SCW_PROFILE non impostato: si usa il profilo ATTIVO — assicurati sia quello giusto)" >&2
}

# Chiede una conferma digitata prima di un'azione distruttiva.
confirm_typed() { # <parola-da-digitare>
  local word="$1" ans
  read -r -p "Per procedere scrivi '$word': " ans
  [ "$ans" = "$word" ] || die "annullato."
}
