#!/usr/bin/env bash
#
# publish.sh — pubblica una release a partire da un tag git, in un colpo solo:
#   1) crea il tag git (se non esiste) sul commit corrente e lo pusha su origin
#   2) build + push delle 3 immagini  →  …:TAG          (03-build-push.sh)
#   3) deploy/rollout di quel TAG sul cluster           (05-deploy.sh)
#
# Uso:  ./publish.sh v4
#
# TAG è FORZATO al valore passato: niente ambiguità anche se sul commit ci sono
# più tag git. Presuppone il bootstrap già fatto una volta (00-04).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TAG="${1:?uso: ./publish.sh <tag>   (es. ./publish.sh v4)}"
export TAG

echo ">> Pubblico la release '$TAG'"

# Avviso (non bloccante) se ci sono modifiche non committate: il tag punta
# all'ultimo commit, ma le immagini useranno i file ATTUALI.
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  echo ">> NOTA: working tree con modifiche non committate — il tag '$TAG' punta" >&2
  echo "   all'ultimo commit, ma le immagini includeranno le modifiche attuali." >&2
fi

# 1. tag git sul commit corrente (idempotente) + push su origin (non bloccante)
if git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo ">> Tag git '$TAG' già esistente: lo riuso."
else
  echo ">> Creo il tag git '$TAG' su HEAD ..."
  git -C "$ROOT" tag "$TAG"
fi
echo ">> Pusho il tag '$TAG' su origin ..."
git -C "$ROOT" push origin "$TAG" || echo ">> (push del tag non riuscito: proseguo comunque)"

# 2. build + push immagini (tag passato esplicito)
"$HERE/03-build-push.sh" "$TAG"

# 3. deploy (tag esplicito; termina con il watch dell'IP dell'Ingress: Ctrl-C per uscire)
"$HERE/05-deploy.sh" "$TAG"
