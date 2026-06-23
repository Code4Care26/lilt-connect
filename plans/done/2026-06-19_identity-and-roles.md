# Plan: Identità per-nome (magic link simulato) + frontend backend-only

## Description

Simulazione realistica di autenticazione per il prototipo, senza login vero.
L'utente inserisce un **nome utente** e preme "Invia magic link": il **backend**
deriva il ruolo dal nome (come se autenticasse) e l'utente entra subito. Da quel
momento ogni richiesta porta l'identità (il nome) e il backend ne ricava il
ruolo, usandolo per le letture role-aware.

Contestualmente il **backend diventa l'unica fonte dati**: si rimuove il mock
frontend (`api/mockDb.js` + i dati seed di `data/seed.js`).

### Regola nome → ruolo (unica, vive nel backend)

Nome `strip`+`downcase`: finisce con `staff` → **staff**; finisce con `vol` →
**volunteer**; vuoto/assente → **supporter** (ospite); altrimenti → **supporter**.

## Goals

- Il backend **identifica sempre** il chiamante: ogni request porta `X-Identity-Id` (il nome). Nessun `X-Role`: il ruolo lo deriva il backend a ogni richiesta.
- Login = magic link **immediato**: `POST /api/session {name}` → il backend "autentica", restituisce `{name, role, initials}`. Il frontend memorizza e rimanda il nome.
- Il ruolo per UI/routing **arriva dal backend**, non è calcolato dal client.
- `draft` visibili **solo allo staff**; non-staff (volunteer/supporter/guest) vedono `published` + `cancelled`.
- **Frontend backend-only**: rimuovere `mockDb` e i dati seed; `api === httpApi`. Conservare metadati UI.
- Si cambia ruolo con **logout + login** con un altro nome. RoleSwitcher dev **rimosso**.
- **Seed solo eventi**: candidature/partecipazioni del proprio utente partono vuote. La roster `Applicant` (lato staff) resta come contenuto-evento demo.
- Scope: **solo identificare** (+ letture role-aware). Nessuna autorizzazione/`403` in questo piano.

## Dependencies

- Backend Rails (`backend/`), mock auth (Readme §10). Dopo il piano il frontend **richiede** il backend attivo (niente offline).
- Vitest (frontend) + request spec Rails per il TDD.
- CORS già `headers: :any` → nessuna modifica.

## Initial Status

### Backend
- `base_controller.rb:11-17` — due identità separate via header, default sui seed; nessun ruolo.
- `events_controller.rb:4-6` — `index` ignora l'identità, restituisce tutto.
- `applications_controller.rb` / `participations_controller.rb` — usano `current_volunteer_id`/`current_supporter_id`.
- `seeds.rb` — `VOLUNTEER_ID`/`SUPPORTER_ID` + `VOLUNTEER_APPLICATIONS`/`SUPPORTER_PARTICIPATIONS` (stato per-identità) + `EVENTS` + `APPLICANTS`.
- `routes.rb` — nessun endpoint di sessione/login.

### Frontend
- `api/index.js:13-14` — `api = USE_MOCK ? mockDb : httpApi`, default mockDb.
- `api/mockDb.js` — impl in-memory; `data/seed.js` mescola dati seed + metadati UI (`STATUS_META`,`REASONS`,`CAPACITY`,`VOLUNTEER_APP_META`,`VOLUNTEER_STATUS_ORDER`) + identità (`VOLUNTEER`,`SUPPORTER`).
- `api/http.js:25-53` — header identità solo sui `/mine`, per-chiamata.
- `stores/session.js` — 3 ruoli + identità mock; `setRole` cambia ruolo; `login`/`logout` flag.
- `App.vue:40-49` — **carica tutti e 3 gli store** on mount; `watch(session.role)` per sincronizzare la route; monta `<RoleSwitcher />`.
- `RoleSwitcher.vue` — switch dev supporter/volontario/staff.
- `LoginView.vue` (`/supporter/login`) — email+password+magic-link, tutti chiamano `session.login()` (solo flag), supporter-scoped.
- Store spec girano su `mockDb`.

## Implementation Steps

Convention: `[x]` done, `[ ]` pending. TDD-first sugli step di logica.

### A. Backend — identità per nome + sessione + risoluzione

- [x] [2026-06-19] [identity drafting] Analisi codebase + design (questo documento).
- [x] [2026-06-19] [identity impl] **(spec)** Riscritto `test/integration/api/identity_test.rb`: derivazione ruolo dal nome + `/api/events` role-aware.
- [x] [2026-06-19] [identity impl] **(spec)** Nuovo `test/integration/api/session_test.rb`: `POST /api/session {name}` → `{name, role, initials}`.
- [x] [2026-06-19] [identity impl] Creato `app/services/identity.rb`: `ROLES`, `role_for(name)`, `initials_for(name)`.
- [x] [2026-06-19] [identity impl] Nuovo `app/controllers/api/sessions_controller.rb#create` + rotta `post "session"`.
- [x] [2026-06-19] [identity impl] `base_controller.rb`: `current_identity_id` / `current_role` / `staff?` + shim; rimossi i default sui seed.
- [x] [2026-06-19] [identity impl] `seeds.rb`: rimosso lo stato per-identità; tenuti `EVENTS` e `APPLICANTS`.

### B. Backend — letture role-aware

- [x] [2026-06-19] [identity impl] **(spec)** `events_test.rb` aggiornato (staff vede tutto via `X-Identity-Id`).
- [x] [2026-06-19] [identity impl] `events_controller.rb#index`: `staff?` → tutti; altrimenti `where.not(status: "draft")`.
- [x] [2026-06-19] [identity impl] **(spec)** `applications_test.rb` / `participations_test.rb`: stato iniziale vuoto, `PUT`→`GET`, scoping per identità. **25 test verdi.**

### C. Frontend — backend-only (rimozione mock + dati seed)

- [x] [2026-06-19] [identity impl] Eliminato `src/api/mockDb.js`; `src/api/index.js` → `export const api = httpApi`.
- [x] [2026-06-19] [identity impl] Metadati UI in `src/data/meta.js`; eliminato `src/data/seed.js`; import aggiornati in `staff.js`,`volunteer.js`,`StatesLegendView.vue`.

### D. Frontend — identità per-nome + login magic-link + ruolo dal backend

- [x] [2026-06-19] [identity impl] `src/api/http.js`: `setIdentity(name)` + `X-Identity-Id` su ogni request (no `X-Role`); `session.create`; firme `applications`/`participations` senza id.
- [x] [2026-06-19] [identity impl] `src/stores/session.js`: stato `{name, role, initials}` persistito; `login(name)`→`api.session.create`; `logout()`→ospite; `hydrate()` per il primo request. Ruolo dal backend.
- [x] [2026-06-19] [identity impl] `src/views/LoginView.vue`: input nome + "Invia magic link" → `session.login` + redirect per ruolo; "Continua come ospite".
- [x] [2026-06-19] [identity impl] `App.vue`: rimosso `<RoleSwitcher />`; carica solo lo store del ruolo attivo + reload su cambio identità. Eliminato `RoleSwitcher.vue`.
- [x] [2026-06-19] [identity impl] "Cambia utente" nei profili staff/volontario (logout → `/supporter/login`); supporter mantiene "Esci (torna a ospite)".
- [x] [2026-06-19] [identity impl] `volunteer.js`/`supporter.js` adeguati alle firme `api.*` senza id.
- [x] [2026-06-19] [identity impl] **(extra, richiesta utente)** Rimossa la finta `PhoneStatusBar` in cima al frame telefono (`App.vue` + componente eliminato).

### E. Test store con stub del modulo api

- [x] [2026-06-19] [identity impl] **(spec)** `staff/volunteer/supporter.spec.js` con `vi.mock('../api')` + doppio in-memory `src/test/fakeApi.js`; `http.spec.js` riscritto (solo `X-Identity-Id`, `session.create`). **43 test frontend verdi.**

### F. Doc + verifica end-to-end

- [x] [2026-06-19] [identity impl] `backend/README.md` aggiornato (identità per nome, regola ruolo, `POST /api/session`, backend-only); header-comment `http.js`/`index.js` aggiornati.
- [x] [2026-06-19] [identity impl] `bin/rails test` (25 verdi) + `npm run test` (43 verdi) + `npm run build` OK + **smoke curl** end-to-end (session role-mapping, events role-aware 5/3/3, scoping candidature per identità).

### G. Collegamento candidature volontario ↔ "Gestisci candidature" staff

Richiesta emersa in test: il volontario si candidava ma lo staff non vedeva nulla
(roster `Applicant` mockata e scollegata da `EventApplication`, per giunta hardcoded su `e1`).
Decisioni utente: **ometti la preferenza** ruolo; **contatori live**.

- [x] [2026-06-19] [link-candidature] Migrazione `DropApplicants` + rimosso modello `Applicant`, associazione `Event#applicants`, seed `APPLICANTS`.
- [x] [2026-06-19] [link-candidature] `Event`: `has_many :event_applications`; `as_api` calcola `applicationsCount`/`waitlistCount` live (esclude `supporter`).
- [x] [2026-06-19] [link-candidature] `EventApplication#as_applicant_api` (nome=identità, iniziali/colore derivati, `pref` nullo); `belongs_to :event`. `Identity.color_for`.
- [x] [2026-06-19] [link-candidature] `ApplicantsController` ripuntato su `EventApplication` (index per evento escludendo `supporter`; update=cambia stato; destroy=rifiuta). Rotte e `api.applicants.*` invariati.
- [x] [2026-06-19] [link-candidature] **(spec)** `applicants_test`/`events_test`/`reset_test` riscritti (candidature reali, contatori live, reset svuota stato). **27 test backend verdi.**
- [x] [2026-06-19] [link-candidature] Frontend: `staff` store carica i candidati dell'evento aperto (`loadApplicants`, niente più `e1` hardcoded) + refresh contatori dopo ogni decisione; `CandidatureView` carica al mount; `staff.spec` + `fakeApi` adeguati. **43 test frontend verdi.**
- [x] [2026-06-19] [link-candidature] Smoke loop completo: candidatura volontario → visibile allo staff → approvazione → stato aggiornato lato volontario (`supporter` escluso, contatori live).

### H. Stato "ritirato" (rinuncia non cancella)

Richiesta: chi rinuncia non deve sparire dalle application, ma risultare **ritirato**
(nuovo stato). Decisioni utente: visibile **sia volontario sia staff** (sezione
"Ritirati", non conteggiata); **ri-candidatura consentita** (ritirato → in attesa).

- [x] [2026-06-19] [stato-ritirato] Backend: `EventApplication::STATUSES` + `withdrawn`; `Event::MANAGED_STATUSES` (staff vede anche i ritirati) vs `CANDIDATURE_STATUSES` (contatori, esclude withdrawn); `ApplicantsController#index` su `MANAGED_STATUSES`.
- [x] [2026-06-19] [stato-ritirato] **(spec)** `applicants_test`/`events_test`: ritirato elencato ma non conteggiato. **27 backend verdi.**
- [x] [2026-06-19] [stato-ritirato] Frontend volontario: `withdraw`/`confirmDropOut` → `withdrawn` (niente più delete); `cancelSupporter` resta rimozione; flag `stWithdrawn`; meta "Ritirato"; ri-candidatura (stream + "Le mie adesioni" → "Candidati di nuovo").
- [x] [2026-06-19] [stato-ritirato] Frontend staff: getter `withdrawnList` + sezione "Ritirati" (read-only, non conteggiata) in `CandidatureView`.
- [x] [2026-06-19] [stato-ritirato] **(spec)** `volunteer.spec` aggiornato (ritiro→withdrawn, resta in lista, re-apply). **44 frontend verdi.**
- [x] [2026-06-19] [stato-ritirato] Smoke: candidatura → ritiro (resta "ritirato", contatore −1) → ri-candidatura.

## Risks

- **Niente offline**: la PWA richiede il backend attivo.
- **Refactor App.vue** (load del solo ruolo attivo + reload su login) tocca l'hydration: rischio di regressioni nello stato iniziale/deep-link; coprire con smoke.
- **Login globale e logout nei profili**: cambia il flusso di navigazione (oggi default supporter + RoleSwitcher); verificare i redirect per ruolo.
- **Fiducia sul nome**: il backend si fida di `X-Identity-Id`; il ruolo è una pura funzione del nome (nessuna verifica possibile, ed è voluto).
- **Collisioni di nome**: due persone che scelgono lo stesso nome condividono identità/stato. Accettabile per il prototipo.
- **Colonne DB invariate** (`volunteer_id`/`supporter_id`) alimentate da `current_identity_id`; le colonne `events.applications_count`/`waitlist_count` restano nello schema ma sono **inutilizzate** (contatori ora calcolati live).
- **(RISOLTO)** ~~Roster `Applicant` statica scollegata~~ → blocco G: "Gestisci candidature" ora legge le candidature reali (`EventApplication`); tabella `Applicant` rimossa.
- **`pref` (preferenza ruolo) assente**: lato staff la riga preferenza è vuota (scelta "ometti"); se servisse, va catturata alla candidatura (sheet di selezione ruolo).
- **N+1 sui contatori**: `as_api` interroga `event_applications` per evento; accettabile per il volume del prototipo.

## Context

- **Ticket**: nessuno (richiesta diretta in sessione).
- **Branch**: `feat/identity-and-roles` (off `main`).
- Decisioni (via domande all'utente, 2026-06-19):
  - **Trasporto ruolo**: solo `X-Identity-Id`; ruolo derivato dal backend a ogni request (supera la precedente scelta `X-Identity-Id`+`X-Role`).
  - **Magic link**: login immediato al click.
  - **Seed**: solo eventi; utenti puliti.
  - **RoleSwitcher**: rimosso, sostituito dal login per nome.
  - **Identità**: nome libero, ruolo per suffisso (`staff`/`vol`/else) calcolato dal backend (supera il precedente registry statico e l'identità `guest` separata: l'ospite è semplicemente un supporter senza nome).
  - **Frontend backend-only** + **store spec con stub `api`** (decisi in precedenza, confermati).

## Notes

- CORS già permissivo → nessuna modifica.
- Autorizzazione per ruolo (`403`) fuori scope → piano successivo.
- `data/seed.js` eliminato (nome fuorviante con soli metadati) → metadati in `data/meta.js`.
- Storico decisioni superate (per tracciabilità): registry statico di identità fisse, header `X-Role` esplicito, identità `guest` separata — tutti rimpiazzati dal modello "nome → ruolo".
