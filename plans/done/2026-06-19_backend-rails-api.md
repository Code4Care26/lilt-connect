# Plan: Backend Rails API-only (parità col mock frontend)

## Description

Costruire il backend `backend/` del monorepo LILT come da Readme §10: **Ruby on
Rails in modalità API-only (JSON) + SQLite**. Scope deciso con l'utente:
**parità col mock del frontend**. Il backend deve implementare **esattamente gli
stessi metodi/shape** già esposti da `frontend/src/api/mockDb.js`, così che il
frontend possa essere agganciato aggiungendo un `src/api/http.js` con la stessa
interfaccia e switchando su `VITE_API_MODE=http` — **senza toccare gli store**
(piano già documentato in `frontend/src/api/index.js`).

Modello dati deciso: **mirror denormalizzato** — le tabelle e i serializzatori
restituiscono gli stessi campi del mock (`dateLabel`, `poster`, `icon`, `badge`,
`slots`, `roles`, ecc.), mantenendo gli **stessi id stringa** (`e1..e5`, `p1..p9`)
per swap istantaneo lato frontend.

Auth: **mock** (Readme §10) — nessun login reale; identità volontario/supporter
correnti risolte server-side dal seed (eventuale override via header).

## Goals

- App Rails 8 API-only in `backend/` con SQLite, dentro lo stesso git (monorepo).
- Endpoint REST 1:1 con i metodi di `mockDb` (events, applicants, applications,
  participations + reset), JSON identico alle shape del seed.
- Seed Rails che porta i dati di `frontend/src/data/seed.js` (EVENTS, APPLICANTS,
  stati iniziali, applicazioni volontario, partecipazioni supporter).
- CORS abilitato per il dev server Vite.
- Test di richiesta (request specs) che fissano il contratto JSON.
- Documentare in un punto solo la corrispondenza endpoint ↔ metodo mock, così lo
  step successivo (scrivere `http.js`) è meccanico.

## Dependencies

- Toolchain già presente: Ruby 3.4.1, Rails 8.0.5, Bundler 2.6.3, SQLite 3.45 (verificato).
- Frontend mock-only completato (i tre step Staff/Volontario/Supporter sono in `plans/done/`).
- Gem aggiuntiva: `rack-cors` (CORS dev). Nessun'altra dipendenza esterna.
- `.tool-versions` attualmente lista solo `nodejs`; valutare se aggiungere `ruby 3.4.1`.

## Initial Status

**Repository.** Monorepo con `frontend/` (Vue 3 + Pinia + Vite, mock-only) e
`docs/`. **`backend/` non esiste ancora.** `.gitignore` già prevede
`node_modules/` "a qualsiasi profondità (… future backend/)" ma **non** ignora gli
artefatti Ruby (`backend/tmp`, `backend/log`, `*.sqlite3`) — da aggiungere.

**Contratto da rispettare** — superficie esatta di `frontend/src/api/mockDb.js`
(questo è il contratto vincolante, più del modello "ideale" del Readme §9):

| Metodo mock | Ritorno (shape) | Endpoint REST proposto |
|---|---|---|
| `reset()` | `true` | `POST /api/reset` |
| `events.list()` | `Event[]` | `GET /api/events` |
| `events.get(id)` | `Event \| null` | `GET /api/events/:id` |
| `events.create(data)` | `Event` (nuovo, id slug) | `POST /api/events` |
| `events.update(id, patch)` | `Event` aggiornato | `PATCH /api/events/:id` |
| `applicants.listByEvent(eventId)` | `Applicant[]` | `GET /api/events/:event_id/applicants` |
| `applicants.update(id, patch)` | `Applicant` | `PATCH /api/applicants/:id` |
| `applicants.remove(id)` | `true` | `DELETE /api/applicants/:id` |
| `applications.mine()` | `{ [eventId]: status }` | `GET /api/applications/mine` |
| `applications.setStatus(volId, eventId, status)` | mappa aggiornata | `PUT /api/applications/mine/:event_id` (body `{status}`, `null`→delete) |
| `participations.mine()` | `{ [eventId]: true }` | `GET /api/participations/mine` |
| `participations.setJoined(supId, eventId, joined)` | mappa aggiornata | `PUT /api/participations/mine/:event_id` (body `{joined}`) |

**Shape dei record** (da `frontend/src/data/seed.js` + `mockDb.freshState`):

- **Event** (costante `EVENTS` in `frontend/src/data/seed.js`): `id` (stringa
  `e1..e5`), `title`, `kind`, `subtitle`, `dateLabel`, `timeLabel`, `place`,
  `address`, `poster`, `icon`, `badge`, `badgeBg`, `badgeFg`, `desc`*, `roles`
  (string[]), `slots` ({`approved`,`available`}), `candidature`* (int),
  `attesa`* (int), `status` (`draft|published|cancelled`, da `INITIAL_STATUS`),
  `reason` (string|null, da `INITIAL_REASON`). `create` (in `mockDb.js`) genera
  `id` slug `ev-<slug>-<n>` e default vari.
  *NB: `desc`/`candidature`/`attesa` rinominati a fine lavoro in
  `description`/`applicationsCount`/`waitlistCount` su entrambi i lati.
- **Applicant** (costante `APPLICANTS` in `seed.js`): `id` (`p1..p9`), `name`,
  `initials`, `pref`, `color`, `status` (`pending|approved|waitlist`), `eventId`
  (tutti `e1`).
- **Applications correnti** (costante `VOLUNTEER_INITIAL_APP` in `seed.js`):
  `{ e1:'approved', e3:'supporter', e2:'pending', e5:'waitlist' }` — mappa
  eventId→status per l'unico volontario mock `VOLUNTEER` (`v-gm`).
- **Participations correnti** (costante `SUPPORTER_INITIAL_JOINED` in `seed.js`):
  `{ e3:true }` — per l'unico supporter mock `SUPPORTER` (`sup-gm`).

**Note di shape importanti:**
- `roles` è un **array** e `slots` un **oggetto** → in SQLite usare colonne JSON
  (`t.json`) o `serialize`, restituendoli come array/oggetto nel JSON.
- Gli **id sono stringhe**, non interi autoincrement → primary key stringa
  (`create_table … id: :string`) per restituire `e1`, `p1`, slug, identici al mock.
- `applications.mine` / `participations.mine` ritornano una **mappa**, non un array.

**Identità mock** (server-side): volontario `v-gm` (Giulia Marchetti), supporter
`sup-gm`, staff `s-rb`. Per `mine`/`setStatus`/`setJoined` l'utente corrente è
risolto dal seed; opzionale header `X-User-Id` per override (backend-ready, ma il
mock frontend non lo invia).

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare. Ordine **TDD-first** dove c'è logica
(controller/serializzazione): prima la request spec che fissa il contratto JSON,
poi il codice che la fa passare. Lo scaffolding iniziale (rails new, gemfile,
migrazioni, seed) precede i test perché è infrastruttura, non logica di business.

- [x] [2026-06-19 21:01] [backend-plan] Analisi contratto mock + shape dati + toolchain (questo documento)
- [x] [2026-06-19 21:10] [backend-build] **Scaffold** — `rails new backend --api --database=sqlite3` con skip vari. Boot verificato (`bin/rails runner`), `db:create` ok.
- [x] [2026-06-19 21:10] [backend-build] **Gemfile + CORS** — `rack-cors` 3.0.0 installato; `config/initializers/cors.rb` consente origin Vite: `localhost:5173`, `127.0.0.1:5173`, `192.168.1.66:5173` (su richiesta utente, senza trailing slash).
- [x] [2026-06-19 21:15] [backend-build] **.gitignore + .tool-versions** — ignore Ruby/Rails fusi nel `.gitignore` di root (come per il frontend, niente `.gitignore` separato in `backend/`); aggiunto `ruby 3.4.1` a `.tool-versions`.
- [x] [2026-06-19 21:20] [backend-build] **Migrazioni & modelli** — `Event`/`Applicant` con PK stringa, `EventApplication` (rinominato da `Application` su richiesta utente), `Participation`. JSON per `roles`/`slots`, FK applicants→events, indici unique. Migrate ok.
- [x] [2026-06-19 21:25] [backend-build] **Seed** (`db/seeds.rb`) — portati EVENTS/APPLICANTS/applicazioni volontario/partecipazioni supporter da `seed.js`. Idempotente (`Seeds.run!`, figli→padri per la FK). JSON round-trip verificato.
- [x] [2026-06-19 21:25] [backend-build] **Serializzazione** — metodi `#as_api` su Event/Applicant + `.map_for` su EventApplication/Participation. **Chiavi tutte inglesi** (decisione utente "tutto inglese, poi allineo il frontend"): `candidature→applicationsCount`, `attesa→waitlistCount`, `desc→description`.
- [x] [2026-06-19 21:40] [backend-build] [TDD] **Events** — request spec (index/show/show-null/create-slug+default/patch) + `Api::EventsController` + route. Verde.
- [x] [2026-06-19 21:40] [backend-build] [TDD] **Applicants** — request spec (index/patch/delete) + `Api::ApplicantsController` + route. Verde.
- [x] [2026-06-19 21:40] [backend-build] [TDD] **Applications (mine)** — request spec (map/set/blank→delete) + `Api::ApplicationsController` + route. Verde.
- [x] [2026-06-19 21:40] [backend-build] [TDD] **Participations (mine)** — request spec (map/join/unjoin) + `Api::ParticipationsController` + route. Verde.
- [x] [2026-06-19 21:40] [backend-build] [TDD] **Reset** — request spec (muta poi ripristina) + `Api::ResetController` + route. Verde.
- [x] [2026-06-19 21:45] [backend-build] **Doc di aggancio** — `backend/README.md` con tabella endpoint↔metodo, mapping rinomine inglesi e bozza di `frontend/src/api/http.js`.
- [x] [2026-06-19 21:45] [backend-build] **Verifica live** — `curl` su server reale (`:3001`): GET events (chiavi inglesi ok), CORS preflight per `192.168.1.66:5173` ok, reset→true. Suite: 15 test, 51 assert, 0 failure.
- [x] [2026-06-19 21:50] [backend-build] **Allineamento nomenclatura frontend** (richiesto dall'utente, originariamente fuori scope) — rinominati i campi del modello evento in `seed.js`, `mockDb.js`, `staff.js`, `VolunteerEventDetailView.vue`, `SupporterEventDetailView.vue`: `candidature→applicationsCount`, `attesa→waitlistCount`, `desc→description`. Etichette UI italiane e legenda `StatesLegendView` (desc locale) intatte. **27 test vitest verdi**.

## Risks

- **Drift di contratto**: se un campo serializzato non combacia (es. snake vs
  camelCase, `slots` come stringa invece che oggetto) il frontend si rompe in
  modo silenzioso. Mitigazione: request spec che asseriscono le **chiavi esatte**
  del JSON contro il seed del frontend.
- **Primary key stringa in Rails 8 + SQLite**: meno battuto degli id interi;
  attenzione a `id: :string` nelle migrazioni e a `param` non numerici nelle route.
- **`reset` e idempotenza seed**: il mock azzera tutto in memoria; lato DB il
  reset deve troncare/riseminare in modo pulito senza violare le FK.
- **Auth mock vs `mine`**: con identità hardcoded dal seed va bene per la demo,
  ma se in futuro servono più utenti la risoluzione dell'utente corrente va
  ripensata (header già previsto come gancio).
- **Doppia fonte di verità del seed** (JS e Ruby): se il `seed.js` cambia, il
  seed Ruby va riallineato a mano. Annotato nei Notes.
- **`.tool-versions`**: aggiungere o no `ruby 3.4.1`? Scelta non bloccante;
  decidere allo scaffold (vedi Notes).

## Context

- **Ticket**: nessuno (piano nato da richiesta diretta "costruiamo il backend come da Readme").
- **Branch**: `feat/backend-rails-api`, tagliato da `master`. Prima del branch: **fast-forward merge** di `feat/supporter-mock` in `master` (decisione utente: "fai merge in master e poi riparti da lì"), così `master` contiene tutto il frontend + il contratto mock.
- **Readme di riferimento**: `Readme.md` §9 (entità dominio), §10 (stack: Rails API-only + SQLite, auth mock).
- **Contratto vincolante**: `frontend/src/api/mockDb.js`, `frontend/src/api/index.js`, `frontend/src/data/seed.js`, `frontend/src/stores/session.js`.
- **Decisioni utente (2026-06-19)**:
  - Scope = **parità col mock frontend** (no ore donate/turni ricorrenti/comunicazioni in questo piano).
  - Modello dati = **mirror denormalizzato** (campi identici al mock, non il dominio normalizzato §9).
  - Git flow = merge dei feature branch frontend in `master`, poi sviluppo backend su nuovo branch da `master`.

## Notes

- Il **modello "ideale" del Readme §9** (Person STI, Event con `start_time`/`end_time`
  datetime + `recurrence`, ore donate, reportistica) è **rinviato**: questo piano
  punta a sbloccare lo swap del frontend. Un piano successivo potrà evolvere lo
  schema verso §9 dietro lo stesso (o un nuovo) contratto.
- **TDD parziale**: scaffold/gemfile/migrazioni/seed sono infra → non TDD. Tutta
  la logica di controller/serializzazione è coperta da request spec scritte prima.
  Framework di test: **minitest** (default Rails 8) — deciso 2026-06-19 come
  default da hackathon; nessuna gemma extra. Sostituibile con RSpec su richiesta.
- **`.tool-versions`**: deciso di aggiungere `ruby 3.4.1` accanto a `nodejs`
  (2026-06-19) — basso rischio, allinea la toolchain del monorepo.
- **Doppia fonte del seed**: tenere il seed Ruby allineato a `frontend/src/data/seed.js`;
  valutare in futuro un'unica fonte (es. il backend serve anche il seed e il
  frontend smette di avere il proprio).
- Lo step di scrivere `frontend/src/api/http.js` e flippare `VITE_API_MODE` è
  **fuori scope** qui: lasciato pronto dalla "Doc di aggancio".
