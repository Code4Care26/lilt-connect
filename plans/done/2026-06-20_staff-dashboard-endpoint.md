# Plan: Console Staff — fase 2, endpoint reale `GET /api/staff/dashboard`

## Description

Sostituire il mock statico della Console (`frontend/src/data/staffDashboardMock.js`)
con un endpoint backend reale `GET /api/staff/dashboard`, costruito con lo **stesso
approccio ibrido** di `VolunteerStatsController` ("Il tuo impatto"):

- le parti **ancorate agli eventi** sono REALI (eventi pubblicati, capienza dai `slots`,
  `minParticipants`, urgenza da `starts_at`);
- le parti **per-volontario** (candidature in attesa, dormienti, ritiri, riserva,
  affidabilità) sono **generate in modo deterministico e stabile** (seed costante, come
  l'MD5-seed della dashboard volontari), perché i seed non creano `event_applications` →
  un endpoint puramente reale sarebbe vuoto.

Decisione confermata dall'utente (2026-06-20): ibrido come la dashboard volontari, così la
Console è popolata anche con DB vuoto. Quando arriverà lo storico reale per-volontario, si
sostituisce la generazione seeded con query su `event_applications` mantenendo la stessa forma.

## Goals

- `GET /api/staff/dashboard` che restituisce ESATTAMENTE la forma consumata da
  `ConsoleView.vue` (oggi definita in `staffDashboardMock.js`):
  `kpis`, `atRiskEvents[]`, `pendingApplications[]`,
  `volunteerHealth{ dormant[], recentWithdrawals[], stuckWaitlist[], reliability[] }`,
  `waitlistMatches[]`.
- Determinismo: la stessa identità/giornata produce sempre gli stessi numeri (stabile tra
  restart e tra richieste), come `VolunteerStatsController`.
- Wiring frontend: `api.staff.dashboard()` + azione di store; `ConsoleView` legge dallo
  store, non più dall'import statico.
- Rimozione del mock statico (single source of truth = backend; "there is no offline mock").
- Test d'integrazione che blocca il contratto (chiavi + invarianti).

## Dependencies

- Nessuna nuova gem/npm. Rails + Minitest (test/integration/api/*), Vue/Pinia esistenti.
- `Identity.initials_for` / `Identity.color_for` per avatar coerenti.

## Initial Status

- Pattern di riferimento: `backend/app/controllers/api/volunteer_stats_controller.rb`
  (ibrido: `seeded_rng` da MD5 del nome, magnitudini da Event reali, selezione seeded).
- `Event#as_api` (`backend/app/models/event.rb`) espone già `minParticipants`,
  `missingParticipants`, `needsParticipants`, `startsAt`, `slots`, `kind`, `dateLabel`.
- `Event::CANDIDATURE_STATUSES`, `MANAGED_STATUSES`; `EventApplication` con `volunteer_id`,
  `status`, `created_at`.
- Rotte in `backend/config/routes.rb` (namespace `:api`); base in `base_controller.rb`
  (`current_identity_id`, `current_role`, `staff?`).
- Frontend: `frontend/src/api/http.js` (`httpApi`, sezione `volunteer.stats`),
  `frontend/src/api/index.js`, store `frontend/src/stores/volunteer.js`
  (`loadStats()`), `frontend/src/views/ConsoleView.vue` (oggi importa il mock statico),
  `frontend/src/stores/staff.js`.
- Forma target: identica a `frontend/src/data/staffDashboardMock.js`.

## Implementation Steps

Convention: `[x]` = done, `[ ]` = pending. TDD-first: prima il test d'integrazione che
fissa il contratto, poi il controller che lo soddisfa.

- [x] [2026-06-20 01:48] [staff endpoint] Test `backend/test/integration/api/staff_dashboard_test.rb`: 6 test — chiavi esatte di `kpis` e delle 5 sezioni; ogni riga con le chiavi attese; `atRiskEvents` da eventi `published` reali con `missing>0`; coerenza KPI↔sezioni; `waitlistMatches` su eventi reali; **determinismo** (due richieste → JSON identico).
- [x] [2026-06-20 01:50] [staff endpoint] `Api::StaffDashboardController#show`: ibrido alla VolunteerStatsController. `seeded_rng` con seed costante (MD5 "lilt-staff-dashboard"). Eventi a rischio reali da `slots` (`confirmed` seeded sotto il minimo → `missing>0`), `daysToStart` da `starts_at`. Parti per-volontario da `ROSTER` fisso, slice disgiunte, `initials`/`color` via `Identity`.
- [x] [2026-06-20 01:50] [staff endpoint] Rotta `get "staff/dashboard"` in `routes.rb`.
- [x] [2026-06-20 01:51] [staff endpoint] Frontend: `api.staff.dashboard()` in `http.js`; `dashboard` state + `loadDashboard()` nello store staff.
- [x] [2026-06-20 01:52] [staff endpoint] `ConsoleView.vue`: legge da `store.dashboard` (computed + guard `v-if`/stato "Carico…"), `onMounted(loadDashboard)`.
- [x] [2026-06-20 01:52] [staff endpoint] Eliminato `frontend/src/data/staffDashboardMock.js` (nessun riferimento residuo).
- [x] [2026-06-20 01:53] [staff endpoint] Verifica: `bin/rails test` 40/40, `npm run build` OK, `npm test` 54/54, screenshot reale della Console servita dall'endpoint (e1 5/11, e3 10/24, sezioni popolate).

## Risks

- **Determinismo vs `daysToStart`**: `daysToStart` dipende da `Time.current` e dagli
  `starts_at` seedati (giu/lug 2026). In demo (oggi 2026-06-20) è corretto; nei test non si
  asserisce il valore esatto ma solo il tipo (Integer) e le invarianti strutturali.
- **Drift di contratto**: la forma è duplicata (controller + ConsoleView). Mitigato dal test
  che asserisce le chiavi; se cambia la forma, il test fallisce.
- **Ruolo**: per semplicità (come `volunteer/stats`) l'endpoint non forza `staff?`. È sotto
  `/api/staff/` e usato solo dalla tab staff. Eventuale gate `staff?` → step successivo se serve.

## Context

- **Ticket**: nessuno (repo hackathron).
- **Branch**: `feat/staff-dashboard-endpoint` (da `main`).
- Fase 1 (mock) completata: `plans/done/2026-06-20_staff-dashboard-mock.md`.

## Notes

- Quando arriverà lo storico reale per-volontario: sostituire la generazione seeded con
  aggregazioni su `event_applications` raggruppate per `volunteer_id` (last `created_at` →
  dormienti; `withdrawn` recenti via `updated_at`; `waitlist` ferme; `approved/(approved+withdrawn)`
  → affidabilità). La forma dell'output e il consumo frontend restano invariati.
