#!/usr/bin/env bash
#
# 07-aggiorna.sh — rebuild + push + rolling update di UN servizio.
# Uso:
#   ./07-aggiorna.sh backend [tag]
#   ./07-aggiorna.sh gosse   [tag]
#   ./07-aggiorna.sh frontend[tag]
# Tag: secondo argomento, oppure timestamp (richiede un tag NUOVO ogni volta,
# altrimenti Kubernetes non riscarica l'immagine).
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd docker; require_cmd kubectl

SVC="${1:?servizio: backend | gosse | frontend}"
TAG="${2:?passa il tag esplicito, es: ./07-aggiorna.sh backend 0.0.2}"

case "$SVC" in
  backend)  CTX=backend;  IMG="${REGISTRY}/${REGISTRY_NS}/lilt-backend:${TAG}" ;;
  gosse)    CTX=gosse;    IMG="${REGISTRY}/${REGISTRY_NS}/lilt-gosse:${TAG}" ;;
  frontend) CTX=frontend; IMG="${REGISTRY}/${REGISTRY_NS}/lilt-frontend:${TAG}" ;;
  *) die "servizio sconosciuto: $SVC (usa backend|gosse|frontend)" ;;
esac

kubectl get deployment "$SVC" >/dev/null 2>&1 || die "Deployment '$SVC' assente. Hai lanciato ./05-deploy.sh?"

say "Login registry ..."; scw registry login region="$REGION"
say "Build $IMG ..."; docker build -t "$IMG" "$ROOT_DIR/$CTX"
say "Push $IMG ...";  docker push "$IMG"

# Se aggiorni il backend e ci sono nuove migration, falle girare PRIMA (una volta)
# con lo stesso tag dell'immagine appena pushata.
if [ "$SVC" = "backend" ]; then
  say "Eseguo il Job di migrazione con la nuova immagine ..."
  kubectl delete job db-migrate --ignore-not-found
  sed "s|BACKEND_IMAGE|${IMG}|g" "$K8S_DIR/migrate-job.yaml" | kubectl apply -f -
  kubectl wait --for=condition=complete job/db-migrate --timeout=300s \
    || { kubectl logs job/db-migrate --tail=50 || true; die "migrazione fallita."; }
fi

say "Rolling update deployment/$SVC → $IMG ..."
kubectl set image "deployment/$SVC" "$SVC=$IMG"

if kubectl rollout status "deployment/$SVC" --timeout=180s; then
  echo ""; say "OK. '$SVC' aggiornato a $IMG"
else
  echo ""; say "Rollout non riuscito entro il timeout. Per tornare indietro:"
  echo "    kubectl rollout undo deployment/$SVC"
  exit 1
fi
