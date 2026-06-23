#!/usr/bin/env bash
#
# 08-https.sh
# Abilita HTTPS sull'host $APP_HOST con cert-manager + Let's Encrypt (HTTP-01).
# Prerequisiti:
#   - $APP_HOST risolve già all'IP pubblico dell'Ingress (A record DNS);
#   - ingress-nginx installato e app deployata (05-deploy.sh).
# Idempotente: rieseguibile senza danni.
. "$(dirname "$0")/config.sh"
require_cmd kubectl

# 1. cert-manager
if ! kubectl get ns cert-manager >/dev/null 2>&1; then
  say "Installo cert-manager ($CERT_MANAGER_VERSION) ..."
  kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
  say "Attendo che cert-manager sia pronto ..."
  kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
  kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s
else
  say "cert-manager già presente: salto l'installazione."
fi

# 2. ClusterIssuer Let's Encrypt (con la tua email ACME)
say "Applico i ClusterIssuer Let's Encrypt (email: $ACME_EMAIL) ..."
sed "s|ACME_EMAIL_PLACEHOLDER|${ACME_EMAIL}|g" "$K8S_DIR/cluster-issuer.yaml" | kubectl apply -f -

# 3. Ingress con host + TLS (riapplica il manifest aggiornato)
say "Applico l'Ingress con host $APP_HOST + TLS ..."
sed "s|APP_HOST_PLACEHOLDER|${APP_HOST}|g" "$K8S_DIR/ingress.yaml" | kubectl apply -f -

# 4. Attendo l'emissione del certificato
say "Attendo l'emissione del certificato (Let's Encrypt, 1-2 min) ..."
if kubectl wait --for=condition=Ready certificate/lilt-tls --timeout=180s 2>/dev/null; then
  echo ""
  say "Fatto. https://$APP_HOST è pronto."
else
  echo ""
  say "Certificato non ancora Ready. Diagnostica:"
  echo "    kubectl describe certificate lilt-tls"
  echo "    kubectl get certificate,order,challenge -A"
fi
