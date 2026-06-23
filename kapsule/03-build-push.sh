#!/usr/bin/env bash
#
# 03-build-push.sh
# Crea (se serve) il namespace del registry, fa login docker via CLI, builda e
# pusha le TRE immagini. IDEMPOTENTE sul namespace.
# NB: NON serve esportare la secret key: il login usa le credenziali della CLI.
TAG="${1:-${TAG:-}}"
if [ -z "$TAG" ]; then echo "ERRORE: passa il tag esplicito, es: $0 0.0.1" >&2; exit 1; fi
export TAG
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd python3; require_cmd docker
scw_account_banner
say "Tag immagine: $TAG"

ns_exists() {
  scw registry namespace list region="$REGION" -o json \
    | NAME="$REGISTRY_NS" python3 -c \
      "import sys,json,os; n=os.environ['NAME']; sys.exit(0 if any(x['name']==n for x in json.load(sys.stdin)) else 1)"
}

[ "$REGISTRY_NS" = "lilt-CAMBIA-2026" ] && die "imposta REGISTRY_NS in config.sh con un nome tuo (è globalmente univoco)."

say "Verifico il namespace registry '$REGISTRY_NS' ..."
if ns_exists; then
  say "Già presente, proseguo."
else
  say "Non presente: lo creo (se il nome è già preso globalmente, qui FALLISCE) ..."
  scw registry namespace create name="$REGISTRY_NS" region="$REGION" is-public=true
fi

say "Login docker sul registry ..."
scw registry login region="$REGION"

build_push() { # <context-dir> <image>
  say "Build $2 ..."
  docker build -t "$2" "$ROOT_DIR/$1"
  say "Push $2 ..."
  docker push "$2"
}

build_push backend  "$BACKEND_IMAGE"
build_push gosse     "$GOSSE_IMAGE"
build_push frontend  "$FRONTEND_IMAGE"

echo ""
say "Immagini pubblicate (tag $TAG):"
echo "    $BACKEND_IMAGE"
echo "    $GOSSE_IMAGE"
echo "    $FRONTEND_IMAGE"
echo ""
say "Fatto. Prossimo passo: ./04-secrets.sh"
