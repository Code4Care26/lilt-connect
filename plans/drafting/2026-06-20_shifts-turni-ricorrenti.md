# Plan: Shifts — turni ricorrenti con raccolta disponibilità e pianificazione

## Description

Aggiungere il concetto di **turno ricorrente (shift)** accanto agli eventi.
A differenza degli eventi — guidati dal volontario, che si candida a una singola
istanza — gli shift sono guidati dallo staff: c'è un bisogno di copertura
ricorrente (settimanale/mensile), si **chiede a tutti la disponibilità**, poi lo
staff **fissa** le assegnazioni su un intervallo temporale e **pubblica** la
pianificazione (vincolante per il volontario, con notifica push).

L'inversione di direzione rispetto agli eventi è il punto centrale del design:

- **Evento**: volontario si candida (`pending`) → staff conferma (`approved`).
- **Shift**: staff apre il bisogno → volontario dichiara disponibilità → staff
  assegna e pubblica.

## Goals

- Modellare turni ricorrenti riusabili, materializzati in occorrenze datate per
  ciclo (settimana/mese).
- Permettere al volontario di dichiarare disponibilità (`yes | maybe | no`) sulla
  griglia di occorrenze di un ciclo aperto.
- Dare allo staff una **board di assegnazione** (matrice occorrenze × volontari)
  per fissare le coperture rispettando la capacità.
- Pubblicare la pianificazione in blocco con realtime SSE + push PWA.
- Riusare integralmente l'infrastruttura esistente (gosse SSE, ruoli `Identity`,
  pattern `WRITE_KEYS`/`as_api`, store Pinia) senza modificare gosse.

## Dependencies

- Backend Rails 8 esistente (`backend/`).
- Servizio SSE gosse esistente (`gosse/`) — nessuna modifica richiesta.
- Frontend Vue 3 + Pinia esistente (`frontend/`).
- Plan PWA web-push in-progress (`plans/in-progress/2026-06-20_pwa-web-push.md`)
  — fornisce il canale push per il trigger `schedule.published`. Lo shift può
  partire anche senza push (degrada a solo-SSE), ma il valore pieno arriva con il
  push agganciato.

## Initial Status

Nessun concetto di turno/ricorrenza esiste oggi. I mattoni da ricalcare:

**Modelli (analogie, NON riuso di tabelle):**
- `backend/app/models/event.rb` — pattern `WRITE_KEYS` (contratto camelCase↔snake),
  `as_api()`, `starts_at` + `duration_minutes` per calcoli ore, `status` enum,
  `slots` per capacità. ShiftSeries/Occurrence ricalcano questo stile.
- `backend/app/models/event_application.rb` — upsert per `[volunteer_id, event_id]`,
  status enum, contatti mock deterministici. ShiftAvailability ricalca l'upsert.
- `backend/app/models/participation.rb` — riga = booleano traslato, unique
  `[supporter_id, event_id]`. ShiftAssignment ricalca questo (riga = sei di turno).

**Controller (pattern simmetrici):**
- `backend/app/controllers/api/events_controller.rb` — visibilità per ruolo, camel↔snake.
- `backend/app/controllers/api/applications_controller.rb` — `mine` map + `PUT` upsert/delete.
- `backend/app/controllers/api/participations_controller.rb` — `mine` map + `PUT` toggle.
- `backend/app/controllers/api/applicants_controller.rb` — vista staff roster + PATCH status.
- `backend/app/controllers/api/staff_dashboard_controller.rb` — KPI `atRiskEvents`
  (analogo: occorrenze sotto-coperte 🔴).
- `backend/app/controllers/api/base_controller.rb` — `current_identity_id`,
  `current_role`, `staff?`, `current_volunteer_id`.

**Ruoli:**
- `backend/app/services/identity.rb` — ruolo da suffisso nome (`*staff`, `*vol`,
  altrimenti supporter). Lo shift coinvolge solo staff + volontario; il supporter
  resta escluso.

**Realtime:**
- `backend/app/services/realtime.rb` — `Realtime.publish` after_commit,
  fire-and-forget verso gosse. Aggiungere i tipi `shifts.changed`,
  `availability.changed`, `schedule.published`.
- `frontend/src/api/stream.js` + `frontend/src/App.vue` (`onRealtime`, debounce
  120ms) — aggiungere i nuovi `type` allo switch e rifetch board/miei-turni.

**Routes:**
- `backend/config/routes.rb` — namespace `/api`, nested resources.

**Frontend store/viste da ricalcare:**
- `frontend/src/stores/staff.js` (decorate, load roster, grouping) → store `shifts` staff.
- `frontend/src/stores/volunteer.js` (`decorate`, `_setStatus`) → vista disponibilità.
- `frontend/src/api/http.js` — singleton `httpApi`, header `X-Identity-Id`.

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare. Step ordinati TDD-first (prima lo
spec che fallisce, poi il codice che lo fa passare) per modelli/controller/logica;
saltato per viste e wiring puramente meccanico.

### Fase 0 — Design e analisi
- [x] [2026-06-20 17:00] [shifts] Brainstorming chiuso con 3 decisioni:
  (A) disponibilità **per-ciclo** (no profilo ricorrente); (B) occorrenze
  **materializzate** alla creazione del ciclo; (C) **pubblicato = vincolante** per
  il volontario (nessuna conferma/decline). Spigoli: chiusura raccolta **manuale**;
  lo staff **può riassegnare anche dopo `published`** (ri-emette `schedule.published`).

### Fase 1 — Modelli e schema
- [ ] [shifts] Spec `ShiftSeries`: validazioni, slug id, parsing `recurrence` (RRULE
  minimale `FREQ=WEEKLY;BYDAY=...`), default capacity. Poi migrazione + modello.
  Campi: `id, title, place, role, kind, recurrence, slot_start, slot_minutes,
  capacity, status (active|paused)`.
- [ ] [shifts] Spec `ShiftCycle`: macchina a stati `collecting → scheduling →
  published → closed`, transizioni valide, `[start_date, end_date]`. Poi
  migrazione + modello. FK `series_id`.
- [ ] [shifts] Spec `ShiftOccurrence`: materializzazione dalle date della series
  dentro `[start_date, end_date]`, `starts_at`/`duration_minutes`/`capacity`,
  contatore `assigned`. Poi migrazione + modello. FK `cycle_id`, `series_id`.
- [ ] [shifts] Spec `ShiftAvailability`: upsert `[volunteer_id, occurrence_id]`,
  enum `preference (yes|maybe|no)`, nota opzionale. Poi migrazione + modello.
- [ ] [shifts] Spec `ShiftAssignment`: unique `[volunteer_id, occurrence_id]`,
  vincolo capacity a livello applicativo (non DB), riga = sei di turno. Poi
  migrazione + modello.
- [ ] [shifts] Servizio `ShiftCycleBuilder` (o metodo su `ShiftCycle`) che
  materializza le occorrenze dalla `recurrence` della series. Spec con date note.

### Fase 2 — Backend API
- [ ] [shifts] Spec request + `Api::ShiftSeriesController` (`GET/POST`, solo staff).
- [ ] [shifts] Spec request + `Api::ShiftCyclesController`: `POST` (apre ciclo +
  materializza occorrenze), `PATCH` (transizione status: chiudi raccolta / pubblica
  / archivia), `GET :id/board` (occorrenze + availability + assegnazioni, staff).
- [ ] [shifts] Spec request + `Api::AvailabilityController`: `PUT /availability/mine/
  :occurrence_id` (upsert o delete se `null`, specchio di `applications/mine`);
  `GET /shifts/open` (cicli `collecting` da compilare, volontario).
- [ ] [shifts] Spec request + `Api::AssignmentsController`: `GET /assignments/mine`
  (turni pubblicati del volontario, specchio di `participations/mine`); azioni staff
  di assegna/rimuovi su occorrenza (rispetto capacity, ammesse anche post-`published`).
- [ ] [shifts] Aggiungere route in `backend/config/routes.rb` sotto `/api`.
- [ ] [shifts] KPI occorrenze sotto-coperte: estendere
  `Api::StaffDashboardController` (o sezione dedicata) con l'analogo di
  `atRiskEvents` per gli shift.

### Fase 3 — Realtime + Push
- [ ] [shifts] `after_commit` su ShiftCycle/Availability/Assignment →
  `Realtime.publish` con tipi `shifts.changed`, `availability.changed`,
  `schedule.published` (payload `{type, cycleId}`). Spec sui publish.
- [ ] [shifts] Distinguere semanticamente **invalidation SSE** (`*.changed`, →
  rifetch) da **evento notificabile** (`schedule.published`, → notifica push anche
  ad app chiusa). Agganciare al canale del plan web-push se presente; altrimenti
  degradare a solo-SSE.
- [ ] [shifts] Frontend: aggiungere i nuovi `type` allo switch in
  `frontend/src/App.vue` (`onRealtime`) → rifetch board / miei turni.

### Fase 4 — Frontend
- [ ] [shifts] Estendere `frontend/src/api/http.js` con i nuovi endpoint.
- [ ] [shifts] Store Pinia `shifts` (staff): board, decorate occorrenze con
  contatori `assigned/capacity`, azioni apri/chiudi/pubblica/assegna. Stile
  `stores/staff.js`.
- [ ] [shifts] **Board view staff** (schermata-eroe): matrice occorrenze ×
  volontari, celle colorate dalla `preference` (✅ sì / 🟡 forse / ➖ no), click per
  assegnare, indicatore occorrenze sotto-coperte 🔴.
- [ ] [shifts] Store + **vista volontario** "compila disponibilità" (griglia
  occorrenze del ciclo aperto, set `yes/maybe/no`) — stile `stores/volunteer.js`.
- [ ] [shifts] Vista volontario "**i miei turni**" (assegnazioni pubblicate).
- [ ] [shifts] Routing + voci navbar per ruolo (staff: gestione shift; volontario:
  disponibilità + miei turni). Supporter escluso.

### Fase 5 — Demo polish
- [ ] [shifts] Seed di una series + un ciclo dimostrabile end-to-end.
- [ ] [shifts] Verifica flusso completo: apri ciclo → 3 volontari compilano →
  staff assegna sulla board → pubblica → push/SSE → volontario vede il turno.

## Risks

- **Espansione date / RRULE**: anche con occorrenze materializzate (scelta B)
  serve un parser di ricorrenza, almeno settimanale per giorni della settimana.
  Tenere il parser minimale (`FREQ=WEEKLY;BYDAY=...`, eventualmente `MONTHLY`),
  non una libreria iCal completa. Rischio scope-creep se si generalizza troppo.
- **Capacity enforcement**: il vincolo "non assegnare oltre capacity" è
  applicativo, non DB (come `slots` su Event). Race possibili tra due staff
  contemporanei — accettabile per hackathon, da notare.
- **Riassegnazione post-`published`** (spigolo deciso): "vincolante" è lato
  volontario, non lato staff. Lo staff può ricoprire un buco → ri-emette
  `schedule.published` con push mirata "il tuo turno è cambiato". Attenzione a non
  spammare push su ogni micro-modifica.
- **Dipendenza push**: se il plan web-push non è ancora mergiato, lo shift degrada
  a solo-SSE (niente notifica ad app chiusa). Non bloccante per la demo del flusso.
- **Identità mock**: la board staff elenca i volontari che hanno espresso
  disponibilità; non esiste un'anagrafica volontari reale (`Identity` deriva il
  ruolo dal nome). La lista è quindi "chi ha compilato", non "tutti i volontari".

### Open questions risolte (dal brainstorming)
- Granularità disponibilità → **per-ciclo** (A).
- Generazione occorrenze → **materializzate alla creazione del ciclo** (B).
- Conferma assegnazione dal volontario → **no, pubblicato = vincolante** (C).
- Chiusura raccolta → **manuale** (staff clicca "chiudi raccolta").
- Modifica dopo pubblicazione → **lo staff può riassegnare anche da `published`**.

## Context

- **Ticket**: nessuno (feature da brainstorming interno).
- **Origine**: sessione "shifts" del 2026-06-20, brainstorming sul concetto di
  turno ricorrente analogo agli eventi.
- **Worktree**: l'implementazione avverrà su un worktree dedicato (da creare al
  passaggio in `in-progress/`, branch tipo `feat/shifts-turni-ricorrenti`).

## Notes

- TDD-first applicato a modelli, servizi di materializzazione e controller (spec
  prima). Saltato per viste Vue e wiring SSE puramente meccanico nello switch di
  `App.vue`.
- Riepilogo entità:
  - `ShiftSeries` — template ricorrente riusabile.
  - `ShiftCycle` — l'"intervallo temporale", contenitore della macchina a stati.
  - `ShiftOccurrence` — istanza datata, unità di disponibilità/assegnazione.
  - `ShiftAvailability` — *cosa offro* (per-ciclo, `yes|maybe|no`).
  - `ShiftAssignment` — *cosa mi tocca* (riga = sei di turno, post-pubblicazione).
- Simmetrie API volute: `PUT /availability/mine/:occurrence_id` ≈
  `PUT /applications/mine/:event_id`; `GET /assignments/mine` ≈
  `GET /participations/mine`.
- Nessuna modifica a gosse: i nuovi tipi passano per lo stesso `/publish`.
