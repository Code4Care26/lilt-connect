# LILT — Backend (Rails API-only)

API JSON per la PWA LILT (`../frontend`). Rails 8 in modalità `--api`, PostgreSQL,
auth **mock** (Readme §10, vedi *Identità e ruoli* sotto). È l'**unica fonte
dati**: il frontend la consuma direttamente via `src/api/http.js` (nessun mock
offline). Le risposte usano chiavi **camelCase, in inglese**.

## Setup

```bash
docker compose up -d db   # PostgreSQL su localhost:5432 (dalla root del repo)
cd backend
bundle install
bin/rails db:setup   # crea il DB ed esegue il seed (app/services/seeds.rb)
bin/rails server     # http://localhost:3000
```

Connessione configurata via env var (default in `config/database.yml`):
`DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME`.
I default combaciano col container `db` del `docker-compose.yml`, quindi in dev
non serve impostare nulla.

Test: `bin/rails test test/integration/api/`

CORS è abilitato per il dev server Vite (`localhost:5173`, `127.0.0.1:5173`,
`192.168.1.66:5173`) in `config/initializers/cors.rb`.

## Contratto: endpoint ↔ metodo mock

Tutte le risposte usano **chiavi camelCase, tutte in inglese**. Rispetto al mock
originale del frontend sono stati rinominati tre campi (il frontend va allineato):

| Frontend mock (vecchio) | Contratto backend (nuovo) |
|---|---|
| `candidature` | `applicationsCount` |
| `attesa` | `waitlistCount` |
| `desc` | `description` |

| Metodo `mockDb` | Verbo + path | Ritorno |
|---|---|---|
| `events.list()` | `GET /api/events` | `Event[]` |
| `events.get(id)` | `GET /api/events/:id` | `Event` \| `null` |
| `events.create(data)` | `POST /api/events` | `Event` (id slug, default) |
| `events.update(id, patch)` | `PATCH /api/events/:id` | `Event` |
| `applicants.listByEvent(eventId)` | `GET /api/events/:event_id/applicants` | `Applicant[]` |
| `applicants.update(id, patch)` | `PATCH /api/applicants/:id` | `Applicant` |
| `applicants.remove(id)` | `DELETE /api/applicants/:id` | `true` |
| `applications.mine()` | `GET /api/applications/mine` | `{ [eventId]: status }` |
| `applications.setStatus(_, eventId, status)` | `PUT /api/applications/mine/:event_id` | mappa aggiornata |
| `participations.mine()` | `GET /api/participations/mine` | `{ [eventId]: true }` |
| `participations.setJoined(_, eventId, joined)` | `PUT /api/participations/mine/:event_id` | mappa aggiornata |
| `session.create(name)` | `POST /api/session` | `{ name, role, initials }` |
| `reset()` | `POST /api/reset` | `true` |

Note:
- `PUT /api/applications/mine/:event_id` con `status` nullo/vuoto **rimuove**
  l'adesione.
- `PUT /api/participations/mine/:event_id` accetta `{ joined: true|false }`.

## Identità e ruoli (auth mock, Readme §10)

Nessun login vero. L'identità è un **nome libero** inviato come header
`X-Identity-Id` su **ogni** richiesta; il backend ne **deriva il ruolo** (è
l'unica fonte di verità — il frontend non lo calcola):

- nome che finisce con `staff` → **staff**; con `vol` → **volunteer**;
  qualsiasi altro / vuoto → **supporter** (l'ospite anonimo è un supporter senza nome).
- regola in `app/services/identity.rb` (case-insensitive, spazi ignorati).

`POST /api/session { name }` simula il **magic link**: "autentica" derivando il
ruolo e restituisce `{ name, role, initials }` (login immediato). Da lì il
frontend manda il nome come `X-Identity-Id`.

Letture role-aware: i `draft` sono visibili **solo allo staff**; gli altri
ruoli vedono `published` + `cancelled`.

Lo stato per-utente (candidature, partecipazioni) **non è seedato**: una nuova
identità parte vuota. I seed creano solo eventi e la roster `Applicant` (demo staff).

## Frontend

Il frontend (`../frontend`) è **backend-only**: `src/api/index.js` usa
direttamente `httpApi` (niente più mock offline). In dev le chiamate `/api/...`
passano dal proxy Vite verso questo server. La `session` store invia l'identità
corrente come `X-Identity-Id` su ogni richiesta tramite `setIdentity` in
`src/api/http.js`.
