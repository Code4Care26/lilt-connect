#!/usr/bin/env bash
#
# Dev launcher: starts the three services that make up the app and stops them
# all together on Ctrl-C. No process manager required.
#
#   ./run.sh
#
# Ports (override via env): Rails 3000, gosse 3002, Vite 5173.
# Vite proxies /api -> Rails and /sse -> gosse (see frontend/vite.config.js), so
# you only ever open http://localhost:5173 in the browser.
#
# Prereqs: backend deps (bundle install), frontend deps (npm install), Go, Docker
# (for the PostgreSQL container, started automatically below).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SECRET="${SSE_PUBLISH_SECRET:-dev-secret}"   # must match between rails and gosse
RAILS_PORT="${RAILS_PORT:-3000}"
GOSSE_PORT="${GOSSE_PORT:-3002}"
VITE_PORT="${VITE_PORT:-5173}"
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"   # gosse cross-instance fan-out

# Stop every service together. `kill 0` signals the whole process group — which
# includes the background jobs below AND their own children (the go-run binary,
# npm's node/vite). Killing each $! alone would orphan those grandchildren.
cleanup() {
  trap - INT TERM EXIT
  echo
  echo "Stopping all services..."
  kill 0
}
trap cleanup INT TERM EXIT

echo "Starting:"
echo "  gosse  -> http://localhost:$GOSSE_PORT   (SSE fan-out)"
echo "  rails  -> http://localhost:$RAILS_PORT   (REST API)"
echo "  vite   -> http://localhost:$VITE_PORT   (open this one)"
echo "  Ctrl-C to stop all."
echo

# PostgreSQL (Rails state) and Redis (gosse fan-out) run in Docker containers
# (see docker-compose.yml). Start them and wait until they accept connections
# before booting the app. Left running after Ctrl-C so data/state survive.
echo "Starting postgres + redis (docker compose)..."
( cd "$ROOT" && docker compose up -d db redis )
until docker compose -f "$ROOT/docker-compose.yml" exec -T db pg_isready -U hackathron >/dev/null 2>&1; do
  sleep 1
done
until docker compose -f "$ROOT/docker-compose.yml" exec -T redis redis-cli ping >/dev/null 2>&1; do
  sleep 1
done
echo "postgres + redis ready."
echo

( cd "$ROOT/gosse" && PORT="$GOSSE_PORT" SSE_PUBLISH_SECRET="$SECRET" REDIS_URL="$REDIS_URL" go run . ) &

# Load gitignored backend/.env (VAPID keys for Web Push) if present, then boot
# Rails. `set -a` auto-exports every var the file defines.
( cd "$ROOT/backend" \
    && { set -a; [ -f .env ] && . ./.env; set +a; } \
    && SSE_PUBLISH_URL="http://localhost:$GOSSE_PORT/publish" \
       SSE_PUBLISH_SECRET="$SECRET" \
       bin/rails server -p "$RAILS_PORT" ) &

( cd "$ROOT/frontend" && npm run dev -- --port "$VITE_PORT" ) &

# Wait for any service to exit; the EXIT trap then tears the rest down.
wait -n
