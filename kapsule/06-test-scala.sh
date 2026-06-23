#!/usr/bin/env bash
#
# 06-test-scala.sh — testare, scalare manualmente, pulire.
# Uso:  ./06-test-scala.sh <comando>
. "$(dirname "$0")/config.sh"
require_cmd kubectl

usage() {
  cat <<EOF
Uso: $0 <comando>

  ip               IP pubblico dell'Ingress
  test             curl all'app (frontend / e API /api/events) via l'IP
  status           pod, service, hpa, ingress e nodi
  scale-pod S N    scala il Deployment S (backend|gosse|frontend) a N repliche
  scale-node N     scala i NODI del pool a N
  pulisci          rimuove app + Ingress (tiene cluster e DB)
  distruggi        cancella cluster, PostgreSQL, Redis e Private Network (!)
EOF
}

get_ip() { kubectl get ingress lilt -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null; }

case "${1:-}" in
  ip)
    get_ip; echo ;;
  test)
    IP="$(get_ip)"; [ -n "$IP" ] || die "IP non ancora assegnato, riprova tra poco."
    echo "== GET / (frontend) =="      ; curl -s -o /dev/null -w "%{http_code}\n" "http://$IP/"
    echo "== GET /api/events (Rails) ==" ; curl -s "http://$IP/api/events" | head -c 400; echo
    ;;
  status)
    echo "== NODES ==" ; kubectl get nodes
    echo "== PODS ===" ; kubectl get pods -o wide
    echo "== SVC ===="  ; kubectl get svc
    echo "== HPA ===="  ; kubectl get hpa
    echo "== ING ===="  ; kubectl get ingress lilt
    ;;
  scale-pod)
    S="${2:?serve il nome del deployment}"; N="${3:?serve il numero di repliche}"
    kubectl scale deployment "$S" --replicas="$N"
    ;;
  scale-node)
    N="${2:?serve il numero di nodi}"
    CID="$(cluster_id)"; [ -n "$CID" ] || die "cluster non trovato"
    POOL_ID="$(scw k8s pool list region="$REGION" cluster-id="$CID" -o json \
      | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['id'])")"
    scw k8s pool update "$POOL_ID" region="$REGION" size="$N"
    ;;
  pulisci)
    kubectl delete -f "$K8S_DIR/ingress.yaml" --ignore-not-found
    for m in frontend gosse backend; do
      kubectl delete deployment "$m" svc "$m" --ignore-not-found
    done
    kubectl delete hpa backend gosse --ignore-not-found
    kubectl delete job db-migrate --ignore-not-found
    say "App rimossa. Cluster e DB restano in piedi."
    ;;
  distruggi)
    scw_account_banner
    say "ATTENZIONE: cancello cluster, PostgreSQL, Redis e Private Network su QUESTO account."
    confirm_typed DISTRUGGI
    CID="$(cluster_id)"; [ -n "$CID" ] && scw k8s cluster delete "$CID" region="$REGION" with-additional-resources=true || true
    PGID="$(pg_id)";    [ -n "$PGID" ] && scw rdb instance delete "$PGID" region="$REGION" || true
    RID="$(redis_id)";  [ -n "$RID" ]  && scw redis cluster delete "$RID" zone="$ZONE" || true
    PNID="$(pn_id)";    [ -n "$PNID" ] && scw vpc private-network delete "$PNID" region="$REGION" || true
    say "Risorse eliminate (la cancellazione dei DB e del cluster è irreversibile)."
    ;;
  *)
    usage ;;
esac
