#!/usr/bin/env bash
#
# 05-deploy.sh
# 1) installa ingress-nginx (se assente) → provisiona un Load Balancer Scaleway;
# 2) esegue il Job di migrazione UNA volta e attende il completamento;
# 3) applica backend/gosse/frontend (con le immagini sostituite) + Ingress;
# 4) mostra l'IP pubblico dell'Ingress.
TAG="${1:-${TAG:-}}"
if [ -z "$TAG" ]; then echo "ERRORE: passa il tag esplicito, es: $0 0.0.1" >&2; exit 1; fi
export TAG
. "$(dirname "$0")/config.sh"
require_cmd kubectl

kubectl get secret "$SECRET_NAME" >/dev/null 2>&1 || die "Secret '$SECRET_NAME' assente. Lancia ./04-secrets.sh"

# Deploy del tag passato esplicitamente: i manifest usano le immagini :$TAG.
say "Deploy del tag: $TAG"

# Sostituisce i placeholder immagine nei manifest (come fa l'echo di hello-kapsule).
render() {
  sed -e "s|BACKEND_IMAGE|${BACKEND_IMAGE}|g" \
      -e "s|GOSSE_IMAGE|${GOSSE_IMAGE}|g" \
      -e "s|FRONTEND_IMAGE|${FRONTEND_IMAGE}|g" "$1"
}

# ---- 1. Ingress controller --------------------------------------------
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  say "Installo ingress-nginx ($INGRESS_NGINX_VERSION) — crea un LB Scaleway ..."
  kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"
  say "Attendo che il controller sia pronto ..."
  kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s
else
  say "ingress-nginx già presente: salto l'installazione."
fi

# ---- 2. Migrazione (una volta, prima del rollout) ---------------------
say "Eseguo il Job di migrazione (db:prepare) ..."
kubectl delete job db-migrate --ignore-not-found
render "$K8S_DIR/migrate-job.yaml" | kubectl apply -f -
if ! kubectl wait --for=condition=complete job/db-migrate --timeout=300s; then
  say "Il Job di migrazione non è completato. Log:"
  kubectl logs job/db-migrate --tail=50 || true
  die "migrazione fallita."
fi

# ---- 3. App + Ingress --------------------------------------------------
for m in backend gosse frontend; do
  say "Applico $m ..."
  render "$K8S_DIR/$m.yaml" | kubectl apply -f -
done
say "Applico l'Ingress (host $APP_HOST) ..."
sed "s|APP_HOST_PLACEHOLDER|${APP_HOST}|g" "$K8S_DIR/ingress.yaml" | kubectl apply -f -

say "Attendo i rollout ..."
kubectl rollout status deployment/backend  --timeout=180s
kubectl rollout status deployment/gosse     --timeout=120s
kubectl rollout status deployment/frontend  --timeout=120s

echo ""
say "Attendo l'IP pubblico dell'Ingress (1-2 min). Ctrl-C per uscire dal watch."
kubectl get ingress lilt -w
