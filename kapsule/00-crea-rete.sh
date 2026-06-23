#!/usr/bin/env bash
#
# 00-crea-rete.sh
# Crea (o riusa) la Private Network su cui vivranno cluster e DB gestiti.
# IDEMPOTENTE: se esiste già una PN con lo stesso nome, la riusa.
# Perché serve: i nodi Kapsule scalano (IP che cambiano), quindi i DB NON sono
# raggiungibili via endpoint pubblico + ACL; stanno sulla stessa PN. Vedi §3.4.
. "$(dirname "$0")/config.sh"
require_cmd scw; require_cmd python3
scw_account_banner

say "Verifico la Private Network '$PN_NAME' in $REGION ..."
ID="$(pn_id)"
if [ -z "$ID" ]; then
  say "Non esiste: la creo ..."
  scw vpc private-network create name="$PN_NAME" region="$REGION" >/dev/null
  ID="$(pn_id)"
else
  say "Già presente."
fi

[ -n "$ID" ] || die "impossibile ottenere l'ID della Private Network."
say "Private Network ID: $ID"
echo ""
say "Fatto. Prossimo passo: ./01-crea-cluster.sh"
