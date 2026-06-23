# Plan: Console Staff — mock frontend-only (dashboard volontari)

## Description

Costruire un **mock puramente frontend** della "Console Staff": una nuova schermata
dashboard che dà allo staff le informazioni utili per **gestire gli eventi e mantenere
attivi i volontari**. In questa fase NON si tocca il backend: i dati vengono da un modulo
mock locale, **modellato con la stessa forma** che avrebbe la risposta reale di un futuro
endpoint `GET /api/staff/dashboard`, così che il passaggio al backend vero sia un semplice
swap della sorgente dati senza riscrivere i componenti.

Obiettivo immediato: **visualizzare** le 4 sezioni proposte per validarne gerarchia,
copy e utilità prima di investire sulle query reali.

## Goals

- Una nuova view staff `ConsoleView.vue` raggiungibile da una tab dedicata.
- Quattro sezioni, ognuna ancorata a dati che l'app ha già (o ricava da `event_applications`):
  - **A. Eventi a rischio** — published sotto il minimo, ordinati per urgenza (mancanti ÷ giorni a `starts_at`).
  - **B. In attesa di risposta** — candidature `pending` ordinate per anzianità (`created_at`).
  - **C. Salute dei volontari** — aggregazione per `volunteer_id`: dormienti, ritiri recenti, riserva mai promossa, affidabilità.
  - **D. Match riserva ↔ eventi scoperti** — `waitlist` su eventi futuri ancora sotto il minimo: promozione in un clic.
- Tre KPI in testa azionabili (eventi a rischio, candidature in attesa, volontari a rischio).
- Riuso dei componenti UI esistenti (`StatusChip`, `ProgressBar`, `Avatar`, `LucideIcon`, pattern `EventCard`).
- Mock isolato in un solo file, forma == contratto futuro dell'endpoint.

## Dependencies

- Nessuna nuova dipendenza npm.
- Vue 3 + Vue Router + Pinia + Tailwind già presenti.
- Componenti UI esistenti in `frontend/src/components/ui/`.

## Initial Status

Frontend Vue 3 (Vite + Pinia + Tailwind + Vue Router). Routing per ruolo in
`frontend/src/router.js`; lo staff ha oggi due tab in `BottomNav.vue` ("Eventi",
"Candidature"). Le schermate staff esistenti:

- `frontend/src/views/EventsView.vue` — lista eventi con chip di stato + azioni (pubblica/annulla/gestisci).
- `frontend/src/views/CandidatureView.vue` — gestione candidature per singolo evento (approva/riserva/rifiuta), barra capienza.
- Store: `frontend/src/stores/staff.js` (getters `decoratedEvents`, liste per stato, conteggi, `fillPct`).
- Metadati/label/enum UI: `frontend/src/data/meta.js`.
- Componenti riusabili: `frontend/src/components/ui/{StatusChip,ProgressBar,Avatar,LucideIcon}.vue`, `frontend/src/components/EventCard.vue`.
- Nav staff: `frontend/src/components/ui/BottomNav.vue` (oggetto `NAVS.staff`).

Dati realmente disponibili (dall'analisi del modello):
- `events`: `status` (draft/published/cancelled), `slots` (→ `minParticipants`), `starts_at`, `duration_minutes`, `kind`, `roles`, `reason`, `applicationsCount`/`waitlistCount`/`missingParticipants`/`needsParticipants` (computed live in `as_api`).
- `event_applications`: `volunteer_id` (nome), `event_id`, `status` (pending/approved/waitlist/supporter/withdrawn), `created_at`.
- Nessuna tabella utenti: lo storico volontario si ricava raggruppando `event_applications` per `volunteer_id`.

Limiti noti (da non simulare come se fossero reali): niente skills/preferenze, niente
"inattivi assoluti" (si conosce solo chi si è candidato ≥1 volta), niente last-login
(proxy = ultimo `created_at`).

## Implementation Steps

Convention: `[x]` = done, `[ ]` = pending.
Nota TDD: è un mock di sola UI con dati statici; non si introduce logica di business da
testare con spec. Si privilegia la verifica visiva (skill `run`/`verify`). Eventuali helper
puri di ordinamento/urgenza, se estratti, andranno coperti da una piccola spec.

- [x] [2026-06-20 HH:MM] [staff dashboard] Analisi modello dati e schermate staff esistenti (completata in questa sessione).
- [x] [2026-06-20 01:25] [staff dashboard] Creato `frontend/src/data/staffDashboardMock.js`: oggetto unico con la forma del futuro `GET /api/staff/dashboard` — `kpis`, `atRiskEvents[]`, `pendingApplications[]`, `volunteerHealth{ dormant[], recentWithdrawals[], stuckWaitlist[], reliability[] }`, `waitlistMatches[]`. Dati coerenti con i seed (e1/e3, nomi inventati con `initials`+`color` da `Identity::PALETTE`).
- [x] [2026-06-20 01:25] [staff dashboard] Creato `frontend/src/views/ConsoleView.vue`: layout sezioni A–D + fascia KPI. Riusa `ProgressBar`/`Avatar`/`LucideIcon` (non `StatusChip`: i toni sono inline per sezione). Bottoni inerti → `ui.showToast('… — demo')`.
- [x] [2026-06-20 01:25] [staff dashboard] Sezione A — card "Eventi a rischio" ordinate per urgenza (`missing/daysToStart`), progress capienza, "Apri candidature" → `CandidatureView`, "Riserva N".
- [x] [2026-06-20 01:25] [staff dashboard] Sezione B — lista "In attesa di una tua risposta", avatar+nome+evento, giorni d'attesa (rosso se ≥5), ordinata per anzianità.
- [x] [2026-06-20 01:25] [staff dashboard] Sezione C — "Salute dei volontari": dormienti / ritiri recenti / riserva ferma / affidabilità (% + barra colorata per soglia).
- [x] [2026-06-20 01:25] [staff dashboard] Sezione D — "Riserva da valorizzare": righe volontario↔evento scoperto con bottone "Promuovi".
- [x] [2026-06-20 01:25] [staff dashboard] Routing: aggiunta route `/console` (name `console`, `meta.role: 'staff'`) in `router.js`. `ROLE_HOME.staff` resta `/events`.
- [x] [2026-06-20 01:25] [staff dashboard] Nav: tab "Console" (icona `LayoutDashboard`, aggiunta a `icons.js`) come **terza** voce di `NAVS.staff` (dopo "Eventi" e "Candidature", invariate).
- [x] [2026-06-20 01:26] [staff dashboard] Verifica: `npm run build` OK, `npm test` 54/54 verdi, screenshot reale della Console (Chrome headless via CDP, identità `anna staff`) — tutte le sezioni rendono correttamente nel frame mobile.

## Risks

- **Mock che diverge dal contratto reale**: mitigato modellando il file mock esattamente
  come il futuro JSON dell'endpoint, così la sostituzione è un solo punto di cambio.
- **Sovrapposizione con `EventsView`**: la Console NON deve duplicare la lista eventi; deve
  essere triage/azione. Tenere la distinzione chiara nel copy e nelle azioni.
- **Aspettativa di interattività**: i bottoni del mock sono inerti. Va comunicato che è una
  fase di sola visualizzazione (eventuale toast "demo" al clic).
- ~~Open question: Console come home staff vs terza tab~~ **RISOLTA** [2026-06-20] →
  terza tab "Console" in cima a `NAVS.staff`; `ROLE_HOME.staff` resta `/events`.

## Context

- **Ticket**: nessuno (repo hackathron, non Nosco).
- **Branch**: `feat/staff-dashboard-mock` (da `main`; il repo non ha `development`).
- Spunto di partenza: dashboard live-ops di riferimento (`https://...minimax.io/live`), reinterpretata sul focus "gestire e mantenere attivi i volontari".
- Forma dati target del futuro endpoint: `GET /api/staff/dashboard` (non implementato in questa fase).

## Notes

- Fase 1 = solo frontend + mock, per validare la UX. Fase 2 (separata) = endpoint reale con
  query di aggregazione su `event_applications`/`events`.
- **Decisione 2026-06-20**: la Console è una **terza tab** — ultima voce di `NAVS.staff`,
  dopo "Eventi" e "Candidature" (invariate); `ROLE_HOME.staff` resta `/events`. Scelta meno
  invasiva e reversibile per un mock di validazione. (Inizialmente messa come prima voce,
  poi spostata in terza posizione su richiesta.)
