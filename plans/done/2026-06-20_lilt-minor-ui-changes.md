# Plan: LILT gocciolina — modifiche minori (ordinamento eventi, navbar, azioni staff)

## Description

Tre gruppi di modifiche richieste sull'app LILT "gocciolina":

1. **Eventi**: ordinati per data evento (dal più vicino in poi, a partire da oggi); gli eventi **passati non sono più visibili**.
2. **Navbar / header**: titolo `LILT` (invariato) con sottotitolo `gocciolina` al posto dell'attuale `Padova · …`.
3. **Azioni staff**: dalla scheda evento → **Modifica** e **Esporta partecipanti**; dall'elenco partecipanti, per ogni persona → **Chiama** (tel:), **WhatsApp** (wa.me), **Scrivi email** (mailto:).

## Goals

- Lo stream eventi (supporter + volontario) mostra solo eventi da oggi in poi, ordinati per data crescente (prossimi prima).
- Header uniforme con sottotitolo `gocciolina` in tutte le viste che oggi mostrano `Padova · …`.
- Lo staff può modificare un evento riusando il form di creazione precompilato, esportare i partecipanti, e contattare ogni partecipante con un tap (telefono / WhatsApp / email).

## Dependencies

- Frontend: Vue 3 + Vite + Pinia + Vue Router + Tailwind.
- Backend: Rails 8 (API-only) + PostgreSQL.
- Per i contatti partecipante serve una **migrazione** (colonne `phone` / `email` su `event_applications`) + popolamento dei valori (vedi Risks: i partecipanti NON sono seedati).
- `PATCH /api/events/:id` esiste già (riusabile per la modifica) — nessuna nuova rotta backend per l'edit.

## Initial Status

### 1. Ordinamento / filtro eventi
- **`backend/app/controllers/api/events_controller.rb:6-8`** — `index` ordina per `:created_at` (data di creazione, **non** data evento) e NON filtra i passati:
  ```ruby
  scope = staff? ? Event.all : Event.where.not(status: "draft")
  render json: scope.order(:created_at).map(&:as_api)
  ```
- **`backend/app/models/event.rb:52`** — esiste `starts_at` (datetime reale, serializzato come `startsAt`), oggi inutilizzato per l'ordinamento. `dateLabel`/`timeLabel` sono solo stringhe di display.
- **`backend/app/services/seeds.rb:13-134`** — tutti gli eventi seedati hanno `starts_at` valorizzato (e1 28 giu, e3 6 lug, e2 11 lug, e4 19 lug, e5 24 giu). ⚠️ `Event.create_from_api` (`event.rb:104`) **non** imposta `starts_at`: gli eventi creati da UI hanno `starts_at = nil`.
- Frontend stream pubblico: `frontend/src/views/SupporterStreamView.vue` + `stores/supporter.js`, `frontend/src/views/VolunteerStreamView.vue` + `stores/volunteer.js`. Renderizzano `store.stream` nell'ordine restituito dal backend.

### 2. Header / navbar
Pattern header identico, sottotitolo da cambiare:
- `frontend/src/views/EventsView.vue:34-35` — `LILT` + `Padova · Console staff`
- `frontend/src/views/ConsoleView.vue:40-41` — `LILT` + `Padova · Console staff`
- `frontend/src/views/SupporterStreamView.vue:46-47` — `LILT` + `Padova · Eventi pubblici`
- `frontend/src/views/VolunteerStreamView.vue:25-26` — `LILT` + `Padova · Eventi pubblici`
- `frontend/src/views/LoginView.vue:46` — solo `LILT` (nessun sottotitolo → nessuna modifica)

### 3. Azioni staff
- **Scheda evento** = `frontend/src/components/EventCard.vue`. Emette già `edit` (`EventCard.vue:49`, solo sui draft) ma **EventsView non lo gestisce** (`EventsView.vue:84-91` wira solo publish/manage/cancel). I card `published` hanno "Gestisci candidature" + "Annulla"; nessun "Modifica" né "Esporta".
- **Elenco partecipanti** = `frontend/src/views/CandidatureView.vue` (rotta `/events/:id/applications`, raggiunta da "Gestisci candidature"). Card partecipante a `CandidatureView.vue:62-96/107-128/138-155`. Mostra avatar + nome + `pref` (sempre nil). Nessuna azione di contatto.
- **Dati partecipante** = `EventApplication.as_applicant_api` (`backend/app/models/event_application.rb:28-38`): `{ id, name, initials, color, pref:nil, status, eventId }`. **Nessun phone/email.**
- **Modifica evento**: non esiste vista di edit; esiste solo `frontend/src/views/NewEventView.vue` (creazione) che chiama `store.createEvent`. Backend `PATCH /api/events/:id` già pronto.
- **Export**: nessun export partecipanti. Esiste `frontend/src/api/eventExport.js` come modello di download client-side (ICS, share, clipboard) → riusabile per generare un CSV lato client.
- **Store staff**: `frontend/src/stores/staff.js` — `createEvent` (151), `loadApplicants` (97), `eventById` (55). Manca un'azione di update evento.
- **Router**: `frontend/src/router.js:30-34` rotte staff; manca `/events/:id/edit`.

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare.

### Analisi
- [x] [2026-06-20 02:35] [minors] Analisi codebase: individuati file e punti di modifica per i 3 gruppi; risolte 3 ambiguità con l'utente (vedi Risks).

### Gruppo 1 — Ordinamento + filtro eventi (backend)
- [x] [2026-06-20 04:10] [minors] **Spec** (request spec `events`): un evento con `starts_at` nel passato NON compare per un non-staff; gli eventi futuri tornano ordinati per `starts_at` crescente; eventi con `starts_at = nil` restano visibili.
- [x] [2026-06-20 04:10] [minors] In `backend/app/controllers/api/events_controller.rb#index`: ordinare per `starts_at` ascendente (tiebreak `created_at`), e per il ramo **non-staff** filtrare i passati (`starts_at >= inizio di oggi OR starts_at IS NULL`). Lo staff continua a vedere tutto (per gestire/esportare anche eventi conclusi — vedi Risks). Es.:
  ```ruby
  base  = staff? ? Event.all : Event.where.not(status: "draft")
  scope = staff? ? base : base.where("starts_at >= ? OR starts_at IS NULL", Time.current.beginning_of_day)
  render json: scope.order(Arel.sql("starts_at ASC NULLS LAST"), :created_at).map(&:as_api)
  ```
- [x] [2026-06-20 04:10] [minors] Verifica che gli stream supporter/volontario (`stream` getter) rispettino l'ordine del backend senza riordino lato client che lo annulli.

### Gruppo 2 — Header sottotitolo `gocciolina`
- [x] [2026-06-20 04:10] [minors] Sostituire il sottotitolo `Padova · …` con `gocciolina` in: `EventsView.vue:35`, `ConsoleView.vue:41`, `SupporterStreamView.vue:47`, `VolunteerStreamView.vue:26`. Titolo `LILT` invariato. `LoginView` invariata.

### Gruppo 3 — Azioni staff
**Contatti partecipante (backend)**
- [x] [2026-06-20 04:10] [minors] Migrazione: aggiungere colonne `phone:string`, `email:string` a `event_applications`.
- [x] [2026-06-20 04:10] [minors] Popolare phone/email: poiché i partecipanti NON sono seedati (vedi Risks), generare valori mock **deterministici dal nome** alla creazione dell'application (helper in `Identity`, sullo stile di `initials_for`/`color_for`), persistendoli nelle nuove colonne. Esporli in `EventApplication.as_applicant_api`.
- [x] [2026-06-20 04:10] [minors] **Spec**: `as_applicant_api` include `phone`/`email`; valori deterministici per uno stesso nome.

**Contatti partecipante (frontend)**
- [x] [2026-06-20 04:10] [minors] In `CandidatureView.vue`, per ogni card partecipante (pending/approved/waitlist) aggiungere 3 pulsanti icona: Chiama (`href="tel:…"`), WhatsApp (`https://wa.me/<numero>`), Email (`mailto:…`), visibili solo se il dato è presente.

**Esporta partecipanti**
- [x] [2026-06-20 04:10] [minors] Aggiungere helper CSV in `frontend/src/api/eventExport.js` (colonne: nome, stato, telefono, email) + download, sullo stile di `downloadEventIcs`.
- [x] [2026-06-20 04:10] [minors] Pulsante "Esporta partecipanti" nell'header di `CandidatureView.vue`, che esporta `store.applicants` dell'evento corrente.

**Modifica evento**
- [x] [2026-06-20 04:10] [minors] Adattare `NewEventView.vue` per gestire anche l'edit: prop/route `id` opzionale, precompilare i campi da `store.eventById(id)`, e in `save` chiamare un nuovo `store.updateEvent(id, …)` (che usa `api.events.update` → `PATCH /api/events/:id`) invece di `createEvent` quando in modalità edit. Titolo header "Modifica evento" in edit.
- [x] [2026-06-20 04:10] [minors] Aggiungere azione `updateEvent` in `stores/staff.js` (`api.events.update` + `_replaceEvent` + toast).
- [x] [2026-06-20 04:10] [minors] Aggiungere rotta `/events/:id/edit` in `router.js` (riusa `NewEventView`, `props:true`, `meta:{ role:'staff', hideNav:true }`).
- [x] [2026-06-20 04:10] [minors] Wirato l'emit `@edit` in `EventsView.vue` (`goEdit` → `/events/:id/edit`), così la matita già presente sui card **draft** ora funziona. Per gli eventi **published** la Modifica è esposta nell'header della `CandidatureView` (vedi nota sull'interpretazione "show evento"): non ho aggiunto un secondo pulsante al card per non duplicare/affollare.

## Risks

- **Filtro "passati" e staff (decisione, da confermare a review)**: ho interpretato "gli eventi passati non devono essere visibili" come regola per le viste **pubbliche** (supporter/volontario). Lo staff continua a vedere anche gli eventi conclusi, perché deve poterli modificare/esportare. Se invece anche lo staff deve perderli di vista, va spostato il filtro nel ramo comune. ← **conferma in review**.
- **Partecipanti NON seedati**: `Seeds.run!` seeda solo gli eventi; le `EventApplication` nascono da uso reale (volontario che si candida). Quindi "seed mock contatti" si traduce in: **generazione deterministica dal nome alla creazione** dell'application, persistita nelle nuove colonne. È un ibrido tra le due opzioni proposte (colonne reali + valori mock dal nome) reso necessario dall'assenza di un roster seedato. ← se preferisci seedare un roster demo di partecipanti, è una variante.
- **`starts_at` nullo per eventi creati da UI** — ✅ **RISOLTO (2026-06-20 04:13)**: il form ora usa un date-picker nativo come fonte di verità e invia `startsAt`. `Event::WRITE_KEYS` espone `startsAt`/`durationMinutes` in scrittura e `create_from_api` li imposta. Residuo cosmetico: `timeLabel` viene derivato dall'orario di inizio, quindi un edit perde eventuali range tipo "09:00 – 13:00" (non c'è un campo "ora fine").
- **Formato telefono per `wa.me`**: serve un numero in formato internazionale senza `+`/spazi. Il generatore mock deve produrre un formato coerente (es. `39…`).
- **Copertura test**: il backend ha request spec sugli eventi/applicants; il frontend ha spec su `api/http` e `stream`. Le viste Vue non sembrano avere test, quindi le modifiche UI sono verificate manualmente.

## Context

- **Ticket**: nessuno (modifiche minori richieste in chat).
- **Branch**: `feat/lilt-minor-ui-changes` (da `main`, 2026-06-20).
- **App**: LILT "gocciolina", monorepo `backend/` (Rails) + `frontend/` (Vue), vedi `Readme.md`.
- **Decisioni risolte con l'utente (2026-06-20)**:
  1. Ordinamento eventi futuri = **ascendente (prossimi prima)**.
  2. Contatti partecipante = **aggiungere colonne phone/email + valori mock** (adattato: generati dal nome, vedi Risks).
  3. Modifica evento = **riuso del form di creazione precompilato**.

## Notes

- TDD parziale: spec-first dove c'è copertura backend (ordinamento/filtro eventi, `as_applicant_api`). Le modifiche di solo header e le viste Vue sono cambi di presentazione senza spec dedicate → verifica manuale.
- Export realizzato **client-side** (riuso del pattern di `eventExport.js`, che è in `frontend/src/lib/` non `api/`) per evitare un nuovo endpoint: i partecipanti dell'evento corrente sono già in `store.applicants`.

### [2026-06-20 04:10] [minors] — Implementazione completata

- **Interpretazione "show evento staff"**: lo staff non ha una pagina di dettaglio dedicata. Ho usato la `CandidatureView` (raggiunta da "Gestisci candidature") come superficie "show evento": vi ho messo **Modifica** (matita) ed **Esporta partecipanti** (download) nell'header. La matita di edit sui card **draft** è stata semplicemente wirata alla nuova rotta. Così "da show evento: modifica + esporta" è coperto senza duplicare il pulsante sul card.
- **Contatti**: nuove colonne `phone`/`email` su `event_applications` (migrazione `20260620130000`), popolate da `before_validation on: :create` con `Identity.phone_for`/`email_for` (deterministici dal nome), esposte in `as_applicant_api`. Frontend: nuovo componente riusabile `frontend/src/components/ContactActions.vue` (tel: / wa.me / mailto:) usato nelle 3 sezioni partecipanti. Aggiunte le icone `Phone` e `MessageCircle` al registry `ui/icons.js`.
- **File toccati**: backend → `controllers/api/events_controller.rb`, `models/event_application.rb`, `services/identity.rb`, migrazione, 2 test. Frontend → `views/{EventsView,ConsoleView,SupporterStreamView,VolunteerStreamView,NewEventView,CandidatureView}.vue`, `components/ContactActions.vue` (nuovo), `components/ui/icons.js`, `stores/staff.js`, `router.js`, `lib/eventExport.js`, `stores/staff.spec.js`.
- **Verifica**: `bin/rails test` → 43 run, 0 fail. `npm run test` → 55 pass. `npm run build` → ok.
- **Non implementato di proposito**: nessun guard di rotta sul ruolo (fuori scope).

### [2026-06-20 04:13] [minors] — `startsAt` nel form (estensione richiesta)

Chiuso il limite noto: il form di creazione/modifica ora cattura una data reale.
- Backend: `Event::WRITE_KEYS` ora include `startsAt`/`durationMinutes` (scrivibili); `create_from_api` li imposta. `event_params` li permette automaticamente (derivati da `WRITE_KEYS`). Update già passa da `attrs_from_api`. Nuovi test in `events_test.rb` (POST/PATCH con `startsAt`).
- Frontend (`NewEventView.vue`): i campi Data/Orario sono ora `<input type="date">` + `<input type="time">`. `dateISO` è la fonte di verità: `dateLabel` (etichetta italiana "Sab 12 lug") e `startsAt` (ISO) sono derivati. In edit i picker si precompilano da `ev.startsAt`; per eventi senza data si mantiene l'etichetta originale e non si invia `startsAt`.
