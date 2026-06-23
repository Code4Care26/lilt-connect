# Plan: SSE realtime updates (in-memory, no persistence)

## Description

Aggiungere aggiornamenti realtime alla PWA restando sullo stack attuale (Rails 8
API-only + Puma + Vue 3/Pinia), usando **Server-Sent Events** e **senza
introdurre alcuna persistenza** per il layer realtime: nessun Redis, nessuna
gemma nuova, nessuna tabella di eventi. Il canale SSE trasporta solo segnali di
**invalidazione** (`{type, ...ids}`); il client reagisce ri-eseguendo le
`load()` degli store Pinia esistenti, che ripassano dalle REST API già coperte
dai permessi. La verità durevole resta in SQLite via i modelli attuali.

Contestualmente si alzano i thread di Puma ad almeno 9, perché ogni connessione
SSE occupa un thread per tutta la sua durata (vincolo di `ActionController::Live`).

## Goals

- Quando lo staff pubblica/annulla/modifica un evento o decide su una
  candidatura, volontari e supporter collegati vedono l'aggiornamento **senza
  refresh manuale**.
- Quando un volontario/supporter cambia il proprio stato, lo staff che ha aperto
  la gestione candidature di quell'evento vede il delta in tempo reale.
- Zero persistenza aggiuntiva: pub/sub in-memory, single-process.
- Nessuna dipendenza nuova lato backend o frontend (EventSource è nativo del
  browser; `ActionController::Live` è incluso in Rails 8).
- Degradare con grazia: se l'SSE non è disponibile, l'app continua a funzionare
  esattamente come oggi (le `load()` restano invocabili manualmente / al cambio
  identità).

## Dependencies

- Puma a **processo singolo** (precondizione del pub/sub in-memory). Oggi è così:
  `backend/config/puma.rb` non imposta `workers`/`WEB_CONCURRENCY`.
- Thread Puma ≥ 9 (vedi step 1).
- Proxy dev Vite e proxy prod (Thruster) che non bufferizzano lo stream
  (vedi Risks).

## Initial Status

Stato attuale rilevato in sessione (2026-06-19):

### Backend (`backend/`)
- Rails 8 API-only, SQLite, Puma. `config/application.rb` ha `action_cable`
  **commentato** → nessun ActionCable. `Gemfile` non ha redis/anycable/solid_cable.
- `config/puma.rb:27-28` → `threads 3,3` (default `RAILS_MAX_THREADS=3`). **Da alzare.**
- Tutte le mutazioni passano dallo stesso processo:
  - `app/controllers/api/events_controller.rb` → `create` / `update`
    (publish/cancel/modifica). `index` filtra le `draft`: visibili solo a `staff?`.
  - `app/controllers/api/applicants_controller.rb` → `update` (approve/waitlist) /
    `destroy` (reject) di `EventApplication`.
  - `app/controllers/api/applications_controller.rb` → `update` (candidatura
    volontario per evento).
  - `app/controllers/api/participations_controller.rb` → `update` (toggle
    partecipazione supporter).
  - `app/controllers/api/reset_controller.rb` → `Seeds.run!` (wipe completo).
- `app/controllers/api/base_controller.rb` → identità via header `X-Identity-Id`;
  ruolo derivato da `Identity.role_for` (`app/services/identity.rb`).
- Modelli: `Event`, `EventApplication`, `Participation`. Le `applicationsCount`/
  `waitlistCount` di `Event#as_api` sono **derivate** dalle `event_applications`,
  quindi una decisione su una candidatura cambia anche l'evento.
- `config/routes.rb` → namespace `:api`.

### Frontend (`frontend/`)
- Vue 3 + Pinia + vue-router + PWA. HTTP via `fetch` in `src/api/http.js`
  (URL relativi `/api`, header `X-Identity-Id`). `src/api/index.js` = unico entry.
- Store per ruolo: `src/stores/staff.js`, `volunteer.js`, `supporter.js`,
  `session.js`, `ui.js`. Ognuno ha una `load()` (e lo staff `loadApplicants(id)`).
- `src/App.vue` carica **solo** lo store del ruolo attivo e ricarica al cambio
  identità (`watch` su `session.name|role`, `onMounted`). Punto naturale dove
  montare/smontare la connessione SSE.
- `EventSource` **non supporta header custom** → l'identità per lo stream va
  passata in query string (`/api/stream?identity=...`), non via `X-Identity-Id`.
- `vite.config.js` → proxy `'/api': 'http://localhost:3000'` (forma stringa).

## Implementation Steps

Convention: `[x]` = done, `[ ]` = pending.

- [x] [2026-06-19 23:10] [realtime] Analisi codebase e stesura piano.

### Fase 0 — Puma
- [ ] [2026-06-19 23:10] [realtime] In `backend/config/puma.rb:27` portare il
  default a ≥ 9: `threads_count = ENV.fetch("RAILS_MAX_THREADS", 9)`. Adeguare
  di conseguenza il `pool` in `config/database.yml` se aggancia `RAILS_MAX_THREADS`
  (verificare; SQLite + thread idle in SSE non toccano il DB, ma il pool deve
  coprire i thread che fanno query). Valutare di **riservare** quote: i thread
  totali servono sia per gli stream sia per le REST.

### Fase 1 — Broadcaster in-memory (backend)
- [x] [2026-06-19 23:15] [realtime] Test `backend/test/services/realtime_test.rb`
  (4 test: fan-out, unsubscribe, drop su coda piena). Verde.
- [x] [2026-06-19 23:15] [realtime] `app/services/realtime.rb`: singleton
  thread-safe (`Mutex` + set di `Queue`). API: `subscribe { |queue| ... }`,
  `publish(payload_hash)`. Fan-out non bloccante (drop/skip su coda piena per non
  far morire un publisher per colpa di un client lento). Nessuno stato persistito.

### Fase 2 — Endpoint SSE (backend)
- [x] [2026-06-19 23:18] [realtime] `app/controllers/api/stream_controller.rb`
  con `include ActionController::Live`. Header `text/event-stream` +
  `Cache-Control: no-cache` + `X-Accel-Buffering: no`; greeting `: connected`;
  loop `queue.pop(timeout: HEARTBEAT_INTERVAL)` → `data:`/`: ping`; `ensure`
  unsubscribe + `response.stream.close`. Identità via `params[:identity]`.
  Verificato via curl su un server isolato: header + frame `connected` /
  `events.changed` / `reset` arrivano correttamente.
- [x] [2026-06-19 23:18] [realtime] Rotta `get "stream", to: "stream#show"`.

### Fase 3 — Publish dai punti di mutazione (backend)
- [x] [2026-06-19 23:18] [realtime] Fatto: `after_commit` su `Event`
  (`events.changed {id}`), `EventApplication` (`applications.changed {eventId}`),
  `Participation` (`participations.changed {eventId}`); `reset` esplicito in
  `ResetController`. Suite backend 31/31 verde (i publish sono no-op senza
  subscriber). Dettaglio originale qui sotto.
- [ ] [2026-06-19 23:10] [realtime] Pubblicare **segnali di invalidazione**
  (non lo stato) dopo ogni mutazione andata a buon fine, via callback
  `after_commit` nei modelli `Event`/`EventApplication`/`Participation`
  (deciso — vedi Risks). Per il `reset` (wipe + reseed) pubblicare un singolo
  `reset {}` da `ResetController` dopo `Seeds.run!` (evita una raffica di
  after_commit per ogni riga toccata dal reseed).
  Eventi minimi: `event.updated {id}`, `event.created {id}`,
  `applications.changed {eventId}`, `participations.changed {eventId}`,
  `reset {}`.

### Fase 4 — Client EventSource (frontend)
- [x] [2026-06-19 23:19] [realtime] `src/api/stream.js`: `connectStream(identity,
  onMessage)` / `disconnectStream()`. Chiude la connessione precedente prima di
  riaprire; ignora frame malformati; niente `onerror` (riconnessione del browser).
- [x] [2026-06-19 23:19] [realtime] Spec `src/api/stream.spec.js` (7 test, mock di
  `EventSource`): URL+identity in query, no-identity guest, forward payload,
  frame malformato, close su reconnect/disconnect. Verde.
- [x] [2026-06-19 23:20] [realtime] `src/App.vue`: `openStream()` in `onMounted` e
  nel `watch` su identità; handler `onRealtime` debounced (120ms) → `loadActiveRole()`
  + (staff con `managedEventId`) `loadApplicants()`; `onUnmounted` → `disconnectStream()`.
  Suite frontend 51/51 verde; build di produzione OK.

### Fase 5 — Verifica end-to-end
- [x] [2026-06-19 23:25] [realtime] Backend SSE verificato via curl: header
  corretti + frame `connected`/`events.changed`/`reset`.
- [x] [2026-06-19 23:36] [realtime] **Dev proxy Vite NON bufferizza**: probe
  read-only attraverso lo stack reale (`5173 → 3000`) — il greeting `: connected`
  e gli header (`x-accel-buffering: no`, `transfer-encoding: chunked`) passano
  immediatamente. La forma stringa del proxy in `vite.config.js` basta per SSE.
- [ ] [2026-06-19 23:36] [realtime] Resta solo la conferma **visiva a due client
  nel browser** (es. staff pubblica → lo schermo del volontario si aggiorna senza
  refresh; riconnessione dopo riavvio backend). Mancano i driver browser in
  sessione → da fare manualmente. Tutti i meccanismi sottostanti sono verificati.

## Risks

- **Thread Puma = collo di bottiglia / DoS leggero.** Ogni SSE occupa 1 thread per
  tutta la durata. Con ≥9 thread e pochi client (demo/hackathon) regge, ma N client
  ≥ thread esaurisce il pool e blocca le REST. Mitigazioni: heartbeat per chiudere
  i morti; eventuale cap sul numero di stream; documentare il limite.
- **Single-process è una precondizione non garantita.** Settare `WEB_CONCURRENCY≥2`
  (cluster Puma) rompe il pub/sub in-memory: i worker non condividono memoria.
  Va scritto come vincolo di deploy. Se in futuro serve multi-worker → Redis pub/sub.
- **Buffering dei proxy.** SSE muore se qualcosa bufferizza. Dev: proxy Vite
  (`vite.config.js`) — verificare lo streaming, eventualmente passare alla forma
  oggetto con opzioni. Prod: `thruster` (nel Gemfile) bufferizza/comprime →
  escludere lo stream (`X-Accel-Buffering: no`, no gzip sull'endpoint).
- **EventSource senza header.** L'identità per lo stream passa in query
  string, divergendo dal pattern `X-Identity-Id` del resto dell'API. Per un
  prototipo a auth mock è accettabile (il nome finisce nei log di accesso).
- **Filtro per ruolo / visibilità draft.** `EventsController#index` nasconde le
  `draft` ai non-staff. **Risolto (2026-06-19):** l'SSE manda **solo
  invalidazione** (`{type,id}`); il fan-out NON viene filtrato per ruolo. È il
  re-fetch REST a riapplicare i permessi, quindi una `event.updated` su una draft
  non rivela nulla (la GET la nasconde comunque ai non-staff). Niente logica di
  permessi duplicata nel publish.
- **Nessun replay dei messaggi persi** (niente `Last-Event-ID` perché niente
  persistenza). Accettabile: la riconnessione fa un full re-fetch e si riallinea.

## Context

- **Ticket**: nessuno.
- Sessione: "realtime". Richiesta utente: predisporre aggiornamenti realtime
  restando sullo stack attuale con SSE senza persistere nulla; alzare i thread
  Puma ad almeno 9.
- **Branch**: `feat/sse-realtime` (tagliato da `main`, working tree pulito al
  momento del branch — 2026-06-19).

## Notes

- TDD: per il broadcaster e il composable client si parte da spec; la modifica a
  `puma.rb` e la rotta sono config → niente TDD (giustificato qui).
- Forma del messaggio SSE: **invalidazione**, non snapshot di stato (deciso
  con l'utente 2026-06-19). Mantiene coerente il "senza persistere nulla" e fa
  applicare i permessi alle REST esistenti.
- Publish: **`after_commit` nei modelli** (deciso con l'utente 2026-06-19), col
  `reset` pubblicato dal `ResetController` come singolo evento.
- Identità per lo stream: in **query string** (`/api/stream?identity=...`),
  accettato per il prototipo a auth mock.

### Finding — proxy/heartbeat e rilevamento disconnessioni (2026-06-19)
Durante la verifica è emerso (conferma del rischio già previsto): dietro un
**proxy** (Vite in dev, e in generale nginx/Thruster) la connessione upstream
verso Rails può restare aperta anche quando il client a valle chiude. Rails non
"vede" il disconnect finché non prova a scrivere e fallisce — cioè al prossimo
evento o al **heartbeat**. Con `HEARTBEAT_INTERVAL = 20s` e pochi thread Puma,
una connessione SSE morta tiene il suo thread fino a ~20s (o più, se il proxy
continua a leggere). Implicazioni / follow-up consigliati:
- Considerare un `HEARTBEAT_INTERVAL` più breve (es. 10-15s) per liberare prima
  i thread dei client morti.
- Tenere conto del cap thread (oggi 9): N stream vivi + morti-non-ancora-rilevati
  ≤ thread, altrimenti le REST si bloccano (confermato empiricamente).
- In dev, se il proxy Vite dovesse bufferizzare, passare alla forma oggetto del
  proxy con opzioni esplicite; l'header `X-Accel-Buffering: no` è già impostato.

### ⚠️ Dati di sviluppo toccati durante i test (2026-06-19)
Per errore di ambiente i test via curl/`runner` hanno colpito il **dev server
dell'utente** (DB `storage/development.sqlite3`), non un'istanza isolata. Comandi
eseguiti che hanno mutato dati: `db:prepare`, `Seeds.run!` (runner), `POST
/api/reset`, `PATCH /api/events/e2 (published)`, `PATCH /api/events/e3
(cancelled, Maltempo)`, `PUT /api/applications/mine/e1 (giulia vol → pending)`.
Effetto netto vs seed: lo stato per-utente è stato azzerato dai reset; restano
le mutazioni successive all'ultimo reset (e3 cancelled "Maltempo", e1 con una
candidatura `pending` di "giulia vol"). Ripristinabile con un `POST /api/reset`
o `Seeds.run!` — **da fare solo su conferma dell'utente**. Lezione: usare sempre
una porta/DB isolati (`RAILS_ENV=test` o porta dedicata con pidfile separato).
