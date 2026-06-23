# Plan: App Simpatizzante / Supporter (mock-only)

## Description

Terzo step del sistema LILT, sulla **stessa PWA**. Implementa l'esperienza
**Supporter (simpatizzante)** — il ruolo di **default, anche da non loggato** —
mobile-first, mock-only, riusando l'architettura degli step precedenti (service
layer `src/api/`, store Pinia, libreria UI condivisa, AppShell per-ruolo, toast
condiviso `ui`, persistenza localStorage).

Replica i due design `LILT - Simpatizzante ospite.dc.html` e
`LILT - Simpatizzante loggato.dc.html`. Il supporter ha **due modalità**:

- **Ospite (non loggato)** — sfoglia gli eventi pubblici; in alto a destra un
  pulsante **Accedi** (login opzionale). "Partecipa" apre uno **sheet di login
  opzionale** ("Accedi o registrati" / "Continua come ospite"). Continuando come
  ospite, la disponibilità è inviata ("Inviata come ospite").
- **Loggato** — header con campanella + avatar; "Partecipa" è un **toggle**
  diretto (partecipi ⇄ annulla). Schermata **Dettaglio evento** e **I miei
  eventi** (disponibilità inviate, badge "in attesa", annulla).

A differenza del Volontario **non c'è lifecycle di approvazione**: la
partecipazione è un semplice "disponibilità inviata allo staff".

## Goals

- Sostituire il placeholder `supporter` in `App.vue` con l'app reale.
- Modellare la partecipazione del supporter come **toggle** per evento
  (joined / not-joined), indipendente dai mock di Staff/Volontario.
- Gestire la distinzione **ospite ↔ loggato** con **auth mock** (nessun login
  reale, da Readme §10).
- Riusare i primitivi UI; lo stream supporter è molto vicino a quello volontario.

## Dependencies

- Step Staff + Volontario completati (architettura, UI lib, service layer,
  session store, toast `ui`).
- Nessuna nuova dipendenza npm.

## Initial Status

La PWA ha: `src/api/` (mockDb con migrazione + facade), store `staff`,
`volunteer`, `session` (role default `supporter`, switcher dev), `ui` (toast
condiviso), libreria `components/ui/*`, `App.vue` (AppShell: Staff/Volontario
reali, **placeholder per supporter**), routing per-ruolo con `meta.role`, nav a
2 tab + profilo via avatar.

**Da sapere per il riuso:**
- `App.vue` mostra ancora un **placeholder** per `supporter` → da sostituire.
- `BottomNav` è data-driven per ruolo → aggiungere la voce `supporter` (2 tab:
  Eventi · I miei eventi).
- Eventi nel seed hanno già `kind/subtitle/address/timeLabel/desc`; **manca il
  `badge`** ("Aperto a tutti" / "Posti limitati") usato dallo stream supporter.
- `session` ha solo `role` → aggiungere lo stato **autenticato** (ospite/loggato).
- Lo stream supporter loggato ≈ stream volontario ma con azione singola
  (Partecipa/​toggle) invece della doppia azione + stati adesione.

## Decisioni di design (reuse + nuove)

Valgono le decisioni A–J e la convenzione codice degli step precedenti
(service layer intercambiabile, mock indipendenti per ruolo, mobile-first only,
codice/commenti/route in inglese, copy IT, profilo via avatar + 2 tab).

**Nuove decisioni di questo step:**
- K. **Mock indipendente**: il supporter ha la propria mappa `joined`
  (eventId → bool), separata da Staff/Volontario.
- L. **Auth mock** (Readme §10): `session.authenticated` (default `false` =
  ospite). "Accedi" lo porta a `true` (supporter loggato, mock — niente backend,
  niente registrazione reale). Logout torna ospite. Il login reale e la scelta
  del ruolo via login restano fuori scope (il ruolo si cambia con lo switcher dev).
- M. **Ospite vs loggato**: ospite → banner + pulsante Accedi + sheet di login
  opzionale su "Partecipa" (con "Continua come ospite"); loggato → campanella +
  avatar + toggle diretto.
- N. **Coerenza nav**: 2 tab (Eventi · I miei eventi) + profilo via avatar, come
  Staff/Volontario — **deviazione** dal canvas che mostrava Profilo come tab.
  L'ospite (senza avatar) usa il pulsante Accedi; profilo solo da loggato.
- Aggiungere `badge`/`badgeBg`/`badgeFg` agli eventi del seed condiviso.

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare. TDD-first sulla business logic.

- [x] [2026-06-19 20:31] [draft supporter] **Analisi design** (ospite + loggato): 2 modalità, stream/dettaglio/i-miei-eventi, login opzionale, toggle disponibilità, dati seed.
- [x] [2026-06-19 20:36] [start supporter] **Seed**: aggiunti `badge`/`badgeBg`/`badgeFg` agli eventi; sezione Supporter (`SUPPORTER`, `SUPPORTER_INITIAL_JOINED` prejoin e3). Staff/Volontario verdi.
- [x] [2026-06-19 20:37] [start supporter] **Session**: stato `authenticated` (default false, persistito) + `login()`/`logout()`; `isGuest`; `currentUser` supporter loggato (GM).
- [x] [2026-06-19 20:37] [start supporter] **(TDD) Spec `stores/supporter`**: 6 spec (toggle, myEvents, join/leave idempotenti, badge). Red→green.
- [x] [2026-06-19 20:37] [start supporter] **Service layer**: risorsa `participations` (`mine`, `setJoined`) + `supporterJoined` in state (coperto dalla migrazione `{...fresh,...parsed}`).
- [x] [2026-06-19 20:37] [start supporter] **`stores/supporter.js`**: mappa `joined`, `join`(+guest copy)/`leave`/`toggle`, getter `stream`/`myEvents`/`eventById`; toast via `ui`.
- [x] [2026-06-19 20:40] [start supporter] **Viste**: `SupporterStreamView`, `SupporterEventDetailView`, `SupporterMyEventsView` (empty state), `LoginView`, `SupporterProfileView`, `OptionalLoginSheet`.
- [x] [2026-06-19 20:41] [start supporter] **Shell/nav/router**: rotte `/supporter/*` con `meta.role`; nav supporter (2 tab); `App.vue` su router per tutti i ruoli (rimosso placeholder); `HOME` + redirect `'/'` role-aware.
- [x] [2026-06-19 20:46] [start supporter] **Verifica finale**: `npm test` 27/27, `npm run build` ok (JS 189KB), smoke CDP ospite (Accedi/banner/sheet/continua ospite) + loggato (avatar/toggle/I miei eventi) → zero eccezioni.

## Risks

- **Auth mock**: introdurre `authenticated` tocca la logica dello shell e
  potenzialmente il role-switcher. Tenerlo minimale; "Accedi" = flip booleano,
  schermata login per lo più estetica con CTA funzionanti.
- **Default landing**: il supporter è il ruolo di default; verificare che `'/'`
  e `syncRouteToRole` portino l'ospite a `/supporter/events` senza loop.
- **Deviazione nav (N)**: il canvas mostra 3 tab; noi 2 + avatar. Coerenza con
  l'app prevale sul canvas — annotato.
- **Funnel supporter→volontario** (Readme §3.3): NON implementato in questo step
  (transizione di ruolo); resta per il backend/step futuro.
- **Doppia identità "GM"**: GM è già il volontario loggato; per il supporter
  loggato il canvas riusa GM. Accettabile nel mock (identità per-ruolo nel
  `session`), da disambiguare col backend.

## Context

- **Ticket**: nessuno (hackathon).
- **Branch**: `feat/supporter-mock` (da `feat/volunteer-mock`).
- **Design sorgente**: `LILT - Simpatizzante ospite.dc.html` + `LILT -
  Simpatizzante loggato.dc.html` nel design project "Stream di eventi PWA"
  (`4d15fa66-6651-400e-847c-cd1f33bf36de`).
- **Eventi**: stesso catalogo pubblico (e1..e5) con badge "Aperto a tutti" /
  "Posti limitati".
- **Loggato**: prejoin su e2 (Pigiama Run) nel seed; stato "Inviata allo staff ·
  in attesa".
- **Piani precedenti**: `plans/done/2026-06-19_console-staff-mock.md`,
  `plans/done/2026-06-19_volunteer-mock.md` (architettura riusata).

## Notes

- Branch da creare al passaggio in in-progress (es. `feat/supporter-mock` da
  `feat/volunteer-mock` per ereditare la base).
- Lo sheet di login opzionale e la `LoginView` sono mock: nessuna chiamata reale.
### Bugfix scoperto in verifica (2026-06-19 20:46) — deep-link sotto-pagine
Su full-load/refresh di una sotto-pagina (`/supporter/mine`, `/volunteer/applications`,
`/profile`…) l'app rimbalzava alla home del ruolo: `syncRouteToRole` in `onMounted`
girava **prima** che il router risolvesse la route iniziale, quindi `route.meta.role`
era `undefined` e scattava il replace. Fix: `await router.isReady()` prima di
`syncRouteToRole`. Risolto per tutti e tre i ruoli (bug latente anche su Staff/Volontario).

- Dopo questo step i 3 ruoli saranno coperti in mock → prossimo grande step:
  **switch a backend Rails** (sostituzione impl. in `src/api/`, auth reale,
  unificazione dati cross-ruolo) e domini push (turni/presenze/consuntivo ore).
