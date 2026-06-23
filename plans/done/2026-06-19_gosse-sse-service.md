# Plan: gosse — servizio SSE in Go, fuori da Rails

## Description

Estrarre il layer realtime SSE da Rails e spostarlo in un servizio Go dedicato
nella nuova directory `gosse/`. Rails smette di servire lo stream SSE (niente
più `ActionController::Live`): si limita a **notificare** a gosse, dopo ogni
mutazione, un messaggio di **invalidazione** (lo stesso modello già adottato:
`{type, id/eventId}`, nessuno stato di dominio, nessuna persistenza). gosse
mantiene in memoria l'elenco dei client connessi e fa il fan-out via SSE.

Motivazione: in Go ogni connessione SSE è una **goroutine** (economica), non un
thread Puma. Sparisce il collo di bottiglia dei thread (oggi alzati a 9 proprio
per l'SSE) e il rilevamento delle disconnessioni diventa **immediato** grazie
alla cancellazione del `request.Context()` — niente più thread parcheggiati fino
all'heartbeat.

## Goals

- Un binario Go in `gosse/` che espone:
  - `GET /sse/stream?identity=…` — stream SSE verso i browser;
  - `POST /publish` — endpoint interno chiamato da Rails per iniettare
    un'invalidazione (autenticato con secret condiviso);
  - `GET /healthz` — liveness.
- Rails: rimossi `StreamController`, la rotta `/api/stream` e il pub/sub
  in-memory; `Realtime.publish` resta come **unico seam** ma ora inoltra via
  HTTP a gosse (best-effort, non blocca né fa fallire la mutazione).
- Frontend: l'`EventSource` punta a gosse (via proxy Vite `/sse`), nessun'altra
  modifica al modello "invalida → re-fetch REST".
- Nessuna persistenza aggiunta (coerente con la scelta precedente).
- Suite test verdi su tutti e tre i lati (Go, Rails, frontend).
- Puma: rivalutare/riportare i thread al valore stock (la ragione dell'aumento
  a 9 era l'SSE in-process, che sparisce).

## Dependencies

- Go toolchain installata (verificare `go version`). Solo **stdlib** (`net/http`,
  `sync`, `encoding/json`, `context`, `time`) — nessuna dipendenza esterna.
- Orchestrazione dev a 3 processi (Rails + gosse + Vite): Procfile/script.
- Variabili d'ambiente: lato Rails `SSE_PUBLISH_URL` + `SSE_PUBLISH_SECRET`;
  lato gosse `PORT`, `SSE_PUBLISH_SECRET` (e opz. `ALLOWED_ORIGIN`).

## Initial Status

Stato attuale (post implementazione SSE-in-Rails, branch `feat/sse-realtime`):

### Backend Rails (da modificare/rimuovere)
- `app/controllers/api/stream_controller.rb` — endpoint SSE con
  `ActionController::Live`. **Da rimuovere.**
- `config/routes.rb:9` ca. — `get "stream", to: "stream#show"`. **Da rimuovere.**
- `app/services/realtime.rb` — pub/sub in-memory (`subscribe`/`unsubscribe`/
  `SUBSCRIBERS`/`QUEUE_LIMIT` + `publish`). **Da semplificare:** togliere la parte
  subscribe/queue (la usava solo lo StreamController) e reimplementare `publish`
  come POST verso gosse.
- `app/models/event.rb`, `event_application.rb`, `participation.rb` — i
  `after_commit { Realtime.publish(...) }` **restano invariati** (chiamano sempre
  `Realtime.publish`).
- `app/controllers/api/reset_controller.rb` — `Realtime.publish(type: "reset")`
  **resta invariato.**
- `config/puma.rb:27` — `RAILS_MAX_THREADS` default 9 e `config/database.yml`
  pool 9: **valutare il ritorno a 3** (stock) ora che l'SSE esce da Rails.
- `test/services/realtime_test.rb` — testa subscribe/publish/fan-out in-memory:
  **da riscrivere** (publish ora fa una POST; stub HTTP; no-op se URL non set).

### Frontend (da modificare)
- `src/api/stream.js` — `EventSource('/api/stream?identity=…')`. **Cambiare** in
  `'/sse/stream?identity=…'`.
- `src/api/stream.spec.js` — aggiornare l'URL atteso.
- `vite.config.js` — `proxy: { '/api': 'http://localhost:3000' }`. **Aggiungere**
  `'/sse': 'http://localhost:<gosse-port>'`.
- `src/App.vue` — nessuna modifica (usa `connectStream`/`disconnectStream`).

### gosse/ (nuova)
Non esiste. Da creare con `go.mod`, `main.go`, `hub.go`, `hub_test.go`,
`main_test.go`, `README.md` (+ eventuale `Dockerfile`/Procfile).

## Implementation Steps

Convention: `[x]` done, `[ ]` pending. TDD-first dove ha senso.

### Fase A — gosse: hub + server (Go) ✅
- [x] [2026-06-20] [gosse] `gosse/go.mod` (module `gosse`, go 1.25). Solo stdlib.
- [x] [2026-06-20] [gosse] `hub.go` + `hub_test.go` (4 test): fan-out, unsubscribe,
  publish non-bloccante con drop su canale pieno. Verde.
- [x] [2026-06-20] [gosse] `main.go`: `GET /sse/stream` (header SSE +
  `X-Accel-Buffering: no`, greeting, `select` su canale/ticker 15s/`ctx.Done()`),
  `POST /publish` (secret `X-Sse-Secret`, valida JSON, 204/401/400),
  `GET /healthz`. Bind `HOST` (default `127.0.0.1`) `:PORT` (default 3002).
- [x] [2026-06-20] [gosse] `main_test.go` (httptest, 4 test): healthz, publish
  con/senza secret, publish JSON invalido, stream greeting+data+disconnect via
  context. `go vet` pulito. Verde.
- [x] [2026-06-20] [gosse] `README.md`. Smoke test reale (porta 3099): healthz,
  401/204 su publish, frame `connected`+`data` sullo stream. OK.

### Fase B — Rails: da broadcaster in-process a forwarder HTTP
- [x] [2026-06-20] [realtime] `app/services/realtime.rb` riscritto: niente più
  subscribe/queue; `publish(payload)` POSTa best-effort a `SSE_PUBLISH_URL`
  (fire-and-forget in un thread, timeout 0.5s, `rescue` totale, header
  `X-Sse-Secret`). No-op se URL non configurato. Transport iniettabile per i test.
- [x] [2026-06-20] [realtime] `test/services/realtime_test.rb` riscritto (4 test):
  no-op senza URL; POST con body+secret corretti; secret omesso se non settato;
  errori di delivery sempre swallowed.
- [x] [2026-06-20] [realtime] Rimossi `stream_controller.rb` (git rm) e la rotta
  `get "stream"`.
- [x] [2026-06-20] [realtime] `puma.rb` thread → 3, `database.yml` pool → 5
  (stock); commenti aggiornati (SSE ora in gosse).
- [x] [2026-06-20] [realtime] `bin/rails test`: **34/34 verde**.

### Fase C — Frontend: puntare a gosse ✅
- [x] [2026-06-20] [realtime] `src/api/stream.js`: `BASE = '/sse'` → URL
  `'/sse/stream?identity=…'`; commento aggiornato (gosse, non Rails).
- [x] [2026-06-20] [realtime] `src/api/stream.spec.js`: URL atteso `/sse/stream`.
- [x] [2026-06-20] [realtime] `vite.config.js`: proxy `'/sse'` → `localhost:3002`.
- [x] [2026-06-20] [realtime] vitest **52/52** + `vite build` OK.

### Fase D — Orchestrazione + verifica end-to-end ✅ (browser visivo a parte)
- [x] [2026-06-20] [realtime] Launcher dev. Due opzioni a root: `Procfile.dev`
  (foreman/overmind/hivemind) e **`run.sh`** (zero-install, scelto — l'utente non
  ha tmux/overmind). `run.sh` avvia gosse+rails+vite con lo stesso secret e li
  ferma insieme via `kill 0` (process group → niente orfani da `go run`/`npm`).
  Porte/secret override via env (`RAILS_PORT`/`GOSSE_PORT`/`VITE_PORT`/`SSE_PUBLISH_SECRET`).
- [x] [2026-06-20] [realtime] E2E catena Rails→gosse→client verificata: `rails
  runner` (no server, no mutazione DB) → `Realtime.publish` → POST a gosse →
  `: connected` + `data: {"type":"events.changed","id":"e1"}` su un curl in
  ascolto. Disconnect→goroutine liberata: coperto da `main_test.go` (Count→0).
- [ ] [2026-06-20] [realtime] Resta la conferma **visiva a due client nel
  browser** (manuale, nessun driver in sessione). Avvio: `overmind start -f
  Procfile.dev`, poi apri 5173 in due tab/ruoli.

## Risks

- **Affidabilità Rails→gosse.** Se gosse è giù, l'invalidazione si perde. È
  accettabile (semantica di invalidazione + re-sync al reconnect), MA la POST
  **non deve mai** rallentare o far fallire la mutazione → **fire-and-forget**
  (thread per-POST) + timeout breve + `rescue` (deciso 2026-06-19, sufficiente
  per il prototipo; un worker/coda è un'evoluzione possibile in futuro).
- **Sicurezza di `/publish`.** Senza protezione, chiunque può iniettare
  invalidazioni fasulle. Mitigazioni: **secret condiviso** in header + bind su
  localhost/rete interna. In prod, non esporre `/publish` pubblicamente.
- **Single-process.** L'hub gosse è in memoria: scalare a più istanze gosse
  richiederebbe un bus (Redis pub/sub). Stesso caveat di prima, ora lato Go.
- **CORS.** In dev si passa dal proxy Vite (stessa origin) → nessun CORS. Se il
  browser parlasse direttamente a gosse servirebbe `ALLOWED_ORIGIN`.
- **Tre processi in dev.** Più complessità operativa (serve Procfile/script).
- **Ordine/duplicati.** Best-effort; l'invalidazione è idempotente, quindi
  ririfetch ripetuti non danno problemi.
- **Puma thread → 3 (deciso 2026-06-19).** L'SSE esce da Rails: si torna allo
  stock 3 (thread + pool DB). La POST verso gosse è fire-and-forget, non pesa.

## Context

- **Ticket**: nessuno.
- **Branch**: `feat/gosse-sse`, tagliato da **`main`** (2026-06-20). `main`
  contiene già l'SSE-in-Rails (commit "add SSE") + lavoro successivo; la base
  corretta è quindi `main`, non `feat/sse-realtime` (ormai indietro). I file SSE
  da rimuovere (StreamController, route `/api/stream`, `realtime.rb`, puma 9)
  sono presenti su main.
- **Trasporto Rails→gosse**: HTTP webhook (POST `/publish`) — deciso 2026-06-19.
  Niente Redis/DB/coda.
- Plan correlato: `plans/in-progress/2026-06-19_sse-realtime-updates.md` (l'SSE
  in Rails che qui viene sostituito).

## Notes

- Modello messaggi invariato: **invalidazione** (`{type, id/eventId}`), non stato.
  Rails → gosse passa lo stesso JSON; gosse lo rilancia tal quale come `data:`.
- Vantaggio chiave di Go qui: `r.Context().Done()` rileva il disconnect del
  client **all'istante**, liberando la goroutine — nessun bisogno di dedurlo
  dall'heartbeat (che in Rails lasciava i thread appesi fino a 15s). L'heartbeat
  resta solo per tenere viva la connessione attraverso proxy con idle-timeout.
- Decisioni fissate (2026-06-19): trasporto **HTTP webhook**; publish
  **fire-and-forget**; thread Puma **→ 3**; branch nuovo **feat/gosse-sse** da
  `feat/sse-realtime`. Go disponibile in locale: **go1.25.6**.
