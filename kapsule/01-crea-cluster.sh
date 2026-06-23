#!/usr/bin/env bash
#
# 01-crea-cluster.sh
# Crea il cluster Kapsule agganciato alla Private Network di 00, con un pool di
# nodi in autoscaling, poi installa il kubeconfig.
# IDEMPOTENTE: se un cluster con lo stesso nome esiste già, lo riusa.
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd python3; require_cmd kubectl

PN_ID="$(pn_id)"
[ -n "$PN_ID" ] || die "Private Network '$PN_NAME' non trovata. Lancia prima ./00-crea-rete.sh"

CID="$(cluster_id)"
if [ -z "$CID" ]; then
  say "Creo il cluster '$CLUSTER_NAME' (K8s $K8S_VERSION, pool $NODE_TYPE ${POOL_MIN}-${POOL_MAX}) ..."
  scw k8s cluster create \
    region="$REGION" \
    name="$CLUSTER_NAME" \
    version="$K8S_VERSION" \
    cni=cilium \
    private-network-id="$PN_ID" \
    pools.0.name=pool-default \
    pools.0.node-type="$NODE_TYPE" \
    pools.0.size="$POOL_SIZE" \
    pools.0.min-size="$POOL_MIN" \
    pools.0.max-size="$POOL_MAX" \
    pools.0.autoscaling=true \
    pools.0.autohealing=true \
    --wait
  CID="$(cluster_id)"
else
  say "Cluster '$CLUSTER_NAME' già esistente ($CID): salto la creazione."
fi

[ -n "$CID" ] || die "impossibile ottenere l'ID del cluster."
say "Cluster ID: $CID"
say "Installo/aggiorno il kubeconfig ..."
scw k8s kubeconfig install "$CID" region="$REGION"

say "Nodi del cluster:"
kubectl get nodes
echo ""
say "Fatto. Prossimo passo: ./02-crea-db.sh"
