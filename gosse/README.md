# gosse — SSE fan-out service

Tiny Server-Sent Events service that owns the realtime layer. Rails no longer
streams SSE: after each mutation it POSTs an **invalidation** message to gosse,
which fans it out to the connected browsers. Browsers react by re-fetching
through the normal REST API — gosse holds **no domain state and persists
nothing**.

Each SSE connection is a goroutine (not a Puma thread), and a client disconnect
cancels the request context immediately, so dead connections free their
goroutine at once.

## Endpoints

| Method | Path          | Who calls it | Purpose |
|--------|---------------|--------------|---------|
| `GET`  | `/sse/stream` | browser (`EventSource`, via Vite `/sse` proxy in dev) | long-lived SSE stream |
| `POST` | `/publish`    | Rails (`Realtime.publish`, server-to-server) | inject one invalidation, fanned out to all clients |
| `GET`  | `/healthz`    | ops | liveness + live subscriber count |

### `/publish` contract

Body: the raw invalidation JSON, relayed verbatim as an SSE `data:` frame, e.g.

```json
{"type":"events.changed","id":"e1"}
{"type":"applications.changed","eventId":"e1"}
{"type":"participations.changed","eventId":"e3"}
{"type":"reset"}
```

Must be a single-line JSON value. Authenticated with the `X-Sse-Secret` header
when `SSE_PUBLISH_SECRET` is set (returns `401` otherwise). Returns `204`.

## Configuration (env)

| Var | Default | Notes |
|-----|---------|-------|
| `HOST` | `127.0.0.1` | bind address. Localhost by default so `/publish` is not world-reachable. |
| `PORT` | `3002` | listen port |
| `SSE_PUBLISH_SECRET` | _(empty)_ | shared secret required on `/publish`. **Set it.** Empty = unauthenticated (logged as a warning). |
| `ALLOWED_ORIGIN` | _(empty)_ | `Access-Control-Allow-Origin` for `/sse/stream`. Not needed when the browser reaches gosse through a same-origin proxy (the dev setup). |
| `REDIS_URL` | _(empty)_ | `redis://` or `rediss://` (TLS) URL. **Set it to run more than one instance.** Empty = single-instance, in-memory fan-out only. Pinged at boot — a bad URL aborts startup. |
| `REDIS_CHANNEL` | `gosse.invalidations` | pub/sub channel shared by all instances. Override only if one Redis is shared by multiple environments. |

## Run

```bash
cd gosse
SSE_PUBLISH_SECRET=dev-secret go run .       # dev
go build -o gosse . && ./gosse               # binary
```

Smoke test:

```bash
curl -N localhost:3002/sse/stream            # see ": connected", then ": ping" every 15s
curl -X POST localhost:3002/publish \
  -H "X-Sse-Secret: dev-secret" \
  -d '{"type":"events.changed","id":"e1"}'   # appears as "data: ..." on the stream above
```

## Tests

```bash
go test ./...
```

## Scaling — single process vs. Redis fan-out

The subscriber hub is in memory, so it only knows the clients connected to
**its own** process. With one instance that is all you need. To run more than
one instance, set `REDIS_URL`: gosse then uses a Redis pub/sub channel as the
shared bus.

```
Rails --POST /publish--> gosse (any instance)
                           │ PUBLISH
                           ▼
                         Redis  ──SUBSCRIBE──┬──────────┬──────────┐
                                          gosse #1   gosse #2   gosse #3
                                             │          │          │
                                       fan-out SSE to each instance's clients
```

`/publish` no longer touches the local hub directly: it only `PUBLISH`es to the
channel. Every instance — including the one that received the POST — gets the
message back through its own `SUBSCRIBE` loop and fans it out to its clients, so
each connected browser receives exactly one frame regardless of which instance
holds its stream. No sticky sessions needed.

The pub/sub is **fire-and-forget**: messages are ephemeral, nothing is persisted
in Redis. If Redis restarts a few invalidations may be lost; clients re-sync on
the next message or on SSE reconnect. See `../kapsule/README.md` §3.2.

Local dev (`../run.sh`) starts a Redis container and sets `REDIS_URL`, so the
Redis path is exercised even with a single instance.
