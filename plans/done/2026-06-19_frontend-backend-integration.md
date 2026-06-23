# Plan: Integrazione frontend ↔ backend (usare Rails al posto del mock)

## Description

Collegare la PWA (`frontend/`) al backend Rails (`backend/`) costruito nel piano
precedente, **senza modificare gli store**. Oggi `frontend/src/api/index.js`
esporta `api = mockDb`; questo piano aggiunge un `http.js` con la **stessa
interfaccia** del `mockDb` (chiamate `fetch` verso `/api`) e fa scegliere
mock vs http a un flag env (`VITE_API_MODE`), come già previsto nei commenti di
`index.js` (decision A). Il default resta **mock** (sicuro): l'uso del backend è
opt-in finché non è verificato end-to-end.

Pre-requisito già soddisfatto: la **nomenclatura è allineata** (campi inglesi
`applicationsCount`/`waitlistCount`/`description` su entrambi i lati) e il backend
è testato (15 request spec verdi). Resta solo da costruire il "ponte" HTTP.

## Goals

- `frontend/src/api/http.js`: implementazione `fetch` con la stessa shape di
  `mockDb` (events, applicants, applications, participations, reset).
- `frontend/src/api/index.js`: switch `VITE_API_MODE === 'http' ? httpApi : mockDb`.
- Risolvere il routing dev (proxy Vite vs base URL) in modo che funzioni sia da
  desktop sia da **mobile in LAN** (è il motivo per cui era stato aggiunto
  l'origin CORS `192.168.1.66:5173`).
- Test: unit su `http.js` (fetch mockato) + verifica **end-to-end reale** (Rails
  acceso, PWA in modalità http, gli eventi arrivano dall'API e le mutazioni
  persistono).
- Zero modifiche agli store/viste (a parte, eventuale, l'identità via header).

## Dependencies

- Backend `feat/backend-rails-api` funzionante (`bin/rails db:setup` + `server`).
- Frontend con nomenclatura già allineata (fatto nel piano precedente).
- Nessuna nuova dipendenza npm (si usa `fetch` nativo).

## Initial Status

**Facade attuale** (`frontend/src/api/index.js`): `export const api = mockDb`.
`http.js` non esiste; `VITE_API_MODE`/`fetch(` compaiono solo nei commenti. Gli
store importano `import { api } from '../api'` e non toccano mai l'implementazione.

**Superficie che `http.js` deve coprire** (uso reale negli store, verificato):

| Metodo | Chiamato da | Note |
|---|---|---|
| `events.list()` | volunteer/staff/supporter (load) | — |
| `events.get(id)` | (non usato dagli store oggi) | implementare per completezza |
| `events.create(data)` | staff `createEvent` | `data` con `status` incluso |
| `events.update(id, patch)` | staff publish/cancel | patch `{status}` o `{status,reason}` |
| `applicants.listByEvent('e1')` | staff (load) | — |
| `applicants.update(id, patch)` | staff approve/waitlist | `{status}` |
| `applicants.remove(id)` | staff | ritorna `true` |
| `applications.mine(VOLUNTEER.id)` | volunteer (load) | il backend risolve l'utente server-side |
| `applications.setStatus(VOLUNTEER.id, eventId, status)` | volunteer | `status` null→delete |
| `participations.mine(SUPPORTER.id)` | supporter (load) | — |
| `participations.setJoined(SUPPORTER.id, id, bool)` | supporter | — |
| `reset()` | tutti (bottone "reset dati") | ritorna `true` |

**Identità**: gli store passano `VOLUNTEER.id` (`v-gm`) e `SUPPORTER.id`
(`sup-gm`) a `mine`/`setStatus`/`setJoined`. Coincidono con le identità mock del
seed backend. `http.js` può inoltrarle come header `X-Volunteer-Id` /
`X-Supporter-Id` (il backend le accetta come override, default identico) — così
il comportamento è esplicito e a prova di futuro.

**Config Vite** (`frontend/vite.config.js`): nessun `server.proxy`, nessun
`server.host`. PWA (`vite-plugin-pwa`) attiva con `registerType: 'autoUpdate'`,
ma senza `devOptions.enabled` → il service worker **non** gira in `vite dev`
(rilevante: in dev nessuna cache интерferisce con `/api`).

**Backend pronto**: endpoint sotto `/api`, CORS già abilitato per
`localhost:5173`, `127.0.0.1:5173`, `192.168.1.66:5173`. Bozza di `http.js` già
presente in `backend/README.md`.

## Implementation Steps

Convenzione: `[x]` fatto, `[ ]` da fare. TDD-first dove c'è logica.

- [x] [data] Analisi superficie `api.*`, config Vite, contratto backend (questo documento)
- [x] [2026-06-19 22:00] [integration] **DECISIONE routing dev** → **Vite dev proxy** (scelta utente). `http.js` usa `BASE='/api'` (path relativi); `vite.config.js` ottiene `server.host:true` + `proxy: { '/api': 'http://localhost:3000' }`. Niente CORS necessario in dev; funziona da mobile in LAN via `192.168.1.66:5173`.
- [x] [2026-06-19 22:05] [integration] [TDD] **`http.js` spec** — `frontend/src/api/http.spec.js`, `fetch` mockato, 13 test su verbo+path+body per ogni metodo (get→null, remove→true, setStatus null→`{status:null}`, header identità). Verde.
- [x] [2026-06-19 22:10] [integration] **`http.js`** — `httpApi` con stessa shape di `mockDb`; helper `send()` con `Content-Type` JSON, parse `r.json()` (204→null), inoltro `X-Volunteer-Id`/`X-Supporter-Id`. `BASE='/api'` (path relativi).
- [x] [2026-06-19 22:10] [integration] **`index.js` switch** — `USE_MOCK = VITE_API_MODE !== 'http'`, default mock, opt-in http.
- [x] [2026-06-19 22:10] [integration] **Config dev** — `vite.config.js`: `server.host:true` + `proxy: { '/api': 'http://localhost:3000' }`.
- [x] [2026-06-19 22:15] [integration] **Verifica end-to-end** — Rails (:3000) + Vite http mode (:5174) con proxy. Verificato via `curl` attraverso il proxy: GET events (5, chiavi inglesi), PATCH e2→published **persiste**, `applications/mine` con header identità, POST reset→true (e2 torna draft). Suite frontend completa: **40 test verdi** (27 store + 13 http).
- [x] [2026-06-19 22:20] [integration] **Doc** — `frontend/README.md`: sezione "Data source: mock vs Rails backend" con comandi e nota proxy/LAN; aggiornato l'albero `api/`.

## Risks

- **Routing dev mobile/LAN** (RISOLTO → Vite dev proxy): in `http`
  mode un device mobile su `http://192.168.1.66:5173` **non** può chiamare
  `http://localhost:3000` (localhost = il telefono). Due strade:
  - *Vite proxy* (`/api` → backend) con `server.host:true`: il telefono chiama
    `192.168.1.66:5173/api`, Vite inoltra; **niente CORS necessario**. ⭐ consigliato.
  - *Base URL diretto* `VITE_API_BASE=http://192.168.1.66:3000/api`: richiede CORS
    (già configurato) e che Rails ascolti su `0.0.0.0` (`bin/rails server -b 0.0.0.0`).
- **PWA service worker in produzione**: in build il SW potrebbe cache-are o
  intercettare `/api`. In dev non gira, ma per un deploy va aggiunta una regola
  `NetworkOnly`/`NetworkFirst` per `/api` (fuori scope dev, da annotare).
- **Semantica `reset`**: in mock azzera il localStorage; in http riseme il DB
  Rails per **tutti** i client. Comportamento diverso ma accettabile in demo.
- **localStorage residuo**: passando a http, il blob mock in localStorage resta
  ma non viene letto; nessun impatto funzionale. Eventuale pulizia opzionale.
- **Errori di rete**: il mock non fallisce mai; con http gli store non hanno
  gestione errori. In scope hackathon si accetta; valutare un wrapper minimale.

## Context

- **Ticket**: nessuno (richiesta diretta "iniziare a usare il backend").
- **Branch**: si prosegue su `feat/backend-rails-api`. Il backend è stato
  committato dall'utente (commit "create base backend", "align backend and
  frontend naming", "backend plan done"); vive solo su questo branch, non in
  `master`, quindi l'integrazione deve discenderne. Merge in `master` a fine lavoro.
- **Contratto**: `backend/README.md` (tabella endpoint + bozza `http.js`),
  `frontend/src/api/mockDb.js` (interfaccia di riferimento), `frontend/src/api/index.js`.
- **Dipende da**: piano `backend-rails-api` (in `plans/done/`).

## Notes

- La bozza di `http.js` in `backend/README.md` è il punto di partenza; va
  adattata alla decisione proxy/base URL e all'inoltro identità via header.
- Mantenere il **default mock**: lo switch è opt-in, così il frontend resta
  funzionante anche senza backend acceso (utile in demo/offline).
- Non modificare gli store: se servisse passare l'identità, farlo dentro `http.js`
  leggendo gli id già ricevuti come argomenti (`VOLUNTEER.id`/`SUPPORTER.id`).
