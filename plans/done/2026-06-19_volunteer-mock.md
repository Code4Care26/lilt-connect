# Plan: App Volontario (mock-only)

## Description

Secondo step del sistema LILT, sulla **stessa PWA** già avviata con la console
Staff. Implementa l'**esperienza Volontario** (ruolo `volunteer`), mobile-first,
mock-only, riusando l'architettura posata nello step Staff (service layer
`src/api/`, store Pinia, libreria UI condivisa, AppShell per-ruolo, persistenza
localStorage).

Replica fedelmente il design `LILT - Volontario.dc.html`, 4 frame:

1. **Stream eventi** — lista eventi pubblici con doppia azione: *Partecipa come
   sostenitore* (nessuna approvazione) oppure *Aderisci come volontario* (ruolo
   attivo, soggetto ad approvazione). Chip di stato + azioni contestuali.
2. **Dettaglio evento** — hero, data/luogo, box "Cerchiamo volontari" (ruoli +
   posti), descrizione, CTA sticky che riflette lo stato.
3. **Le mie adesioni** — eventi a cui il volontario è legato, ordinati per stato
   (approvato → in attesa → riserva → sostenitore), con azioni ritira / tira pacco.
4. **Legenda stati** — scheda informativa che spiega il ciclo dell'adesione.

## Goals

- Aggiungere il ruolo `volunteer` alla PWA, attivabile dal role-switcher dev.
- Modellare il **ciclo di vita dell'adesione** del volontario per evento:
  `none → supporter | pending`, `pending/waitlist → (ritira) → none`,
  `approved → (tira pacco) → none`. L'adesione volontario **non è automatica**.
- Riusare al massimo i primitivi UI esistenti; estrarre ciò che ancora manca.
- Mostrare al volontario **solo eventi pubblici** (privacy/visibilità: niente
  bozze né annullati nello stream).

## Dependencies

- Step Staff completato (architettura, UI lib, service layer, session store).
- Nessuna nuova dipendenza npm prevista (riuso Vue/Pinia/Router/Tailwind/Lucide/PWA/Vitest).

## Initial Status

La PWA ha già: `src/api/` (mockDb + facade), `stores/staff.js`, `stores/session.js`
(role default `supporter`, switcher dev), `components/ui/*` (Avatar, StatusChip,
ProgressBar, BottomSheet, Toast, BottomNav per-ruolo, PhoneStatusBar, LucideIcon
+ icons registry), `App.vue` (AppShell che mostra Staff o un placeholder per gli
altri ruoli), router con rotte Staff.

**Da sapere per il riuso:**
- `App.vue` mostra già un placeholder per `volunteer` → va sostituito con l'app reale.
- `BottomNav` è data-driven per ruolo (`NAVS`) → basta aggiungere la voce `volunteer`.
- `Toast` legge `useStaffStore().toast` → **debito**: il toast va estratto in uno
  store `ui` condiviso, altrimenti il Volontario non può emettere toast
  (deferral registrato nello step Staff). Questo step è l'occasione per farlo.
- `mockDb` tiene `applicants` solo per l'evento gestito `e1` (persone generiche).
  Gli eventi nel seed hanno pochi campi; il Volontario richiede campi di dettaglio
  (`kind`, `subtitle`, `address`, `timeLabel`, `desc`) → arricchire il seed eventi.
- ⚠️ Gli **ID evento divergono tra i due design canvas** (es. Pigiama Run è `e3` in
  Staff e `e2` in Volontario): i canvas erano standalone. Va riconciliato un
  unico set di eventi nel seed condiviso.

## Decisioni di design (reuse step Staff)

Valgono A–G e la convenzione codice già fissate per lo Staff (vedi
`2026-06-19_console-staff-mock.md`): service layer intercambiabile, ruoli con
default supporter, AppShell per-ruolo, UI lib condivisa, mobile-first only,
persistenza localStorage, **codice/commenti/endpoint in inglese, copy utente in
italiano**.

**Nuove decisioni di questo step:**
- H. **Identità volontario corrente** nel `session` store (mock): il volontario
  loggato è *Giulia Marchetti (GM)*, coerente con l'applicant `p4` lato Staff.
- I. **Toast condiviso**: estrazione del toast in `stores/ui.js` (risolve il
  deferral dello step Staff); `staff` e `volunteer` lo usano entrambi.
- J. **Visibilità** (rivisto 2026-06-19 19:36): vista la scelta di mock
  indipendenti, il Volontario ha il proprio **catalogo di eventi pubblici** (tutti
  i 5 eventi del seed, come nel canvas). `draft`/`cancelled` sono concetti
  Staff-side **non modellati** nel mock Volontario. ID canonici = quelli Staff
  (e1..e5); gli stati iniziali del Volontario sono mappati per titolo:
  e1 Tour=approved · e3 Pigiama=supporter · e2 Cena=pending · e5 Point=waitlist · e4 none.

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare. TDD-first sulla business logic.

- [x] [2026-06-19 19:33] [draft volunteer] **Analisi design** `LILT - Volontario.dc.html` (4 frame, stati adesione, azioni, toast, dati seed).
- [x] [2026-06-19 19:40] [start volunteer] **Seed eventi condiviso** arricchito (kind/subtitle/address/timeLabel/desc/roles/slots) + sezioni Volunteer (VOLUNTEER, VOLUNTEER_APP_META, VOLUNTEER_INITIAL_APP, VOLUNTEER_STATUS_ORDER). Staff test verdi.
- [x] [2026-06-19 19:41] [start volunteer] **Toast condiviso** `stores/ui.js`: estratto; `Toast.vue` e store `staff` aggiornati; spec Staff aggiornata; 10/10 verdi.
- [x] [2026-06-19 19:42] [start volunteer] **(TDD) Spec `stores/volunteer`**: 10 spec (transizioni, my applications + ordinamento, canWithdraw, conferma drop-out). Red→green.
- [x] [2026-06-19 19:42] [start volunteer] **Service layer**: risorsa `applications` nel mock (`mine`, `setStatus`, `volunteerId` accettato) + `volunteerApp` in state.
- [x] [2026-06-19 19:42] [start volunteer] **`stores/volunteer.js`**: stato adesioni, azioni apply/participate/withdraw/cancelSupporter/askDropOut/confirmDropOut, getter stream/myApplications/decorate.
- [x] [2026-06-19 19:46] [start volunteer] **`session` + `BottomNav` + `App.vue` + router**: `session.currentUser` per ruolo; nav `volunteer`; rotte `/volontario/*` con `meta.role`; AppShell mostra l'app Volontario e tiene URL↔ruolo allineati.
- [x] [2026-06-19 19:47] [start volunteer] **VolunteerStreamView** (frame 1): lista eventi, chip stato, azioni doppie/contestuali, card cliccabile → dettaglio, drop-out sheet.
- [x] [2026-06-19 19:47] [start volunteer] **VolunteerEventDetailView** (frame 2): hero, righe data/luogo, box ruoli + posti (da `slots`), descrizione, CTA sticky per stato.
- [x] [2026-06-19 19:48] [start volunteer] **MyApplicationsView** (frame 3): adesioni ordinate per stato, azioni ritira / annulla partecipazione / tira pacco.
- [x] [2026-06-19 19:48] [start volunteer] **States legend** (frame 4): `StatesLegendView` data-driven da `VOLUNTEER_APP_META`, raggiungibile da header adesioni + profilo. Aggiunti anche `VolunteerProfileView` e `VolunteerDropOutSheet` (sheet condivisa).
- [x] [2026-06-19 19:48] [start volunteer] **Verifica finale**: `npm test` 20/20 (Staff+Volontario), `npm run build` ok (JS 167KB), dev smoke: tutti i moduli compilano 200.

## Risks

- **RISOLTO 2026-06-19 19:34 — unificazione dati cross-ruolo**: l'utente sceglie
  **mock indipendenti per ruolo** ora. Il Volontario ha il proprio stato adesioni
  (per evento, per il volontario corrente); lo Staff resta com'è. L'unificazione in
  un'unica collezione `applications` (eventId, volunteerId, status) — con coerenza
  cross-ruolo — è rimandata allo **step backend** (decisione F). Conseguenza: nel
  mock, approvare GM nello Staff NON si riflette automaticamente lato Volontario.
- **ID evento divergenti** tra i canvas → serve un set unico nel seed; rischio di
  rompere lo Staff se cambio gli ID. Mitigazione: coprire con i test esistenti.
- **Estrazione toast**: toccare `Toast.vue`/`staff` store può rompere i test Staff;
  farlo TDD-guarded.
- **Posti/conteggi nel dettaglio** — RISOLTO: aggiunto `slots: { approved, available }`
  per evento nel seed; il dettaglio li legge da lì (mock per-evento, non statici).

## Context

- **Ticket**: nessuno (hackathon).
- **Branch**: `feat/volunteer-mock` (da `feat/console-staff-mock`, sopra la base Staff committata "feat: add staff views").
- **Design sorgente**: `LILT - Volontario.dc.html` nel design project "Stream di
  eventi PWA" (`4d15fa66-6651-400e-847c-cd1f33bf36de`).
- **Stati adesione** (META dal canvas): `supporter` (teal), `pending` (ambra),
  `approved` (verde), `waitlist` (blu); più `none`.
- **Stato iniziale volontario (GM)**: e1 approved · e3 pending · e5 waitlist · e2 supporter.
- **Piano precedente**: `plans/.../2026-06-19_console-staff-mock.md` (architettura riusata).

## Notes

- Branch da creare al passaggio in in-progress (es. `feat/volunteer-mock` da `master`).
- Il frame 4 (legenda) è documentazione di prodotto: implementarlo come scheda
  statica, non come schermata con logica.
- Dopo questo step resterà il **Simpatizzante**, poi lo **switch a backend Rails**
  (dove l'unificazione dati diventa naturale) e i domini push (turni/presenze/ore).

### Bugfix post-implementazione (2026-06-19 20:09) — "pagina bianca" Volontario
Causa: **schema-drift della persistenza**. Un blob `lilt-mock-db-v1` salvato durante
lo step Staff (con eventi creati dall'utente, es. `ev-blabla-7`) non aveva la chiave
`volunteerApp`, e gli eventi creati non avevano i campi di dettaglio (`slots`/`roles`).
Risultato: due crash a runtime (render-tree Vue) → schermata bianca.
Fix (3 livelli):
1. `mockDb.load()` migra in avanti: `{ ...freshState(), ...parsed }` (backfill chiavi
   mancanti senza perdere i dati utente); `applications.mine/setStatus` difensivi.
2. `volunteer.decorate` fornisce default sicuri (`roles:[]`, `slots:{approved:0,available:0}`).
3. `mockDb.events.create` ora popola i campi Volontario per i nuovi eventi.
Aggiunto spec di regressione (decorate con evento spoglio). Verificato via Chrome DevTools
Protocol: stream/applications/states/detail+azione → **zero eccezioni** sia con blob
legacy sia con dati freschi.
