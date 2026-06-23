# Plan: Console Staff (mock-only)

## Description

Primo step del sistema LILT: una **singola PWA** che servirà tutti e tre i ruoli
(supporter / volontario / staff), partendo dall'implementazione della **console
Staff**. Tutto in mock (nessun backend, nessun login reale): un service layer
intercambiabile prepara il terreno per sostituire i mock con l'API Rails in uno
step successivo, senza toccare gli store.

La console Staff replica fedelmente il design `LILT - Staff.dc.html` (Design
project "Stream di eventi PWA"), che si articola in 4 schermate/stati:

1. **Eventi** — lista con stato bozza/pubblicato/annullato; azioni *Pubblica* e *Annulla*.
2. **Candidature** — per un evento: *Approva* / *Riserva* / *Rifiuta*, con barra capienza.
3. **Sheet "Annulla evento"** — bottom sheet con scelta della causa (modale).
4. **Nuovo evento** — form con *Salva bozza* / *Pubblica*.

## Goals

- Avere una PWA Vue 3 funzionante (mock) con la console Staff completa e fedele al design.
- Stabilire le **fondamenta riusabili** per i ruoli successivi:
  - service layer mock in `src/api/` con interfaccia stabile (swap mock→http futuro);
  - store Pinia che parlano solo col service layer;
  - libreria di componenti UI condivisi (`src/components/ui/`);
  - shell + routing per-ruolo con switcher di ruolo (default `supporter`).
- Persistenza dello stato mock in `localStorage` + reset, così le azioni Staff
  restano visibili tra reload (utile per popolare/demoare).

## Dependencies

- Node 25.4.0 (già impostato via `asdf`, `.tool-versions`).
- Vue 3 (`<script setup>`), Vite 6, Pinia, Vue Router 4.
- Tailwind CSS **v4** (plugin `@tailwindcss/vite`, niente `tailwind.config.js`) — "on the edge".
- `lucide-vue-next` per le icone chrome.
- `vite-plugin-pwa` per il manifest/installabilità.
- (TDD) Vitest + `@vue/test-utils` per gli spec dello store — vedi Risks.

## Initial Status

Lo scaffolding è stato avviato (NON definitivo, rivedibile in questo piano).
File già presenti in `frontend/`:

- `package.json` — deps Vue/Vite/Tailwind4/Pinia/Router/Lucide/PWA.
- `vite.config.js` — plugin vue + tailwind + PWA (manifest LILT Staff).
- `index.html` — root, font Inter, theme-color.
- `src/style.css` — `@import "tailwindcss"`, design tokens via `@theme`, keyframes (toast/scrim/sheet).
- `src/main.js` — bootstrap app + pinia + router.
- `src/router.js` — rotte Staff: `/eventi`, `/eventi/nuovo`, `/eventi/:id/candidature`, `/profilo`.
- `src/data/seed.js` — dati mock dal design (eventi, applicants, status, reasons, capacity).
- `src/stores/staff.js` — store Pinia (traduzione del `DCLogic` del design).

**Debito noto da correggere in questo piano:** `src/stores/staff.js` importa
`seed.js` direttamente. Va rifattorizzato per passare dal **service layer**
(`src/api/`), altrimenti lo swap mock→backend toccherebbe gli store (viola la
decisione A).

Nessuna view/componente UI ancora creata → zero UI renderizzata. `npm install`
non ancora eseguito.

## Decisioni di design concordate (vedi Context)

A. **Service layer mock**: store → `src/api/*` → impl. intercambiabile (mock/http).
B. **Ruoli**: store `session` con `role` (default `supporter`), role-switcher dev in localStorage.
C. **Shell per-ruolo**: `AppShell` sceglie la `BottomNav` per ruolo; route guard; privacy a livello di vista.
D. **Libreria UI condivisa**: `src/components/ui/` (StatusBar, BottomNav, Toast, BottomSheet, Chip, Avatar, EventCard…).
E. **Layout: mobile-first per TUTTI i ruoli, Staff incluso. Desktop ignorato per ora** (nessun layout responsivo desktop). Colonna mobile centrata, niente bezel finto. (Aggiornato 2026-06-19 19:00 su indicazione utente: il Readme dice "Staff prevalentemente desktop" ma per ora si fa solo mobile.)
F. **Dominio**: modelliamo le entità del Readme (Person, Event, Application con storico non-booleano) nei mock; UI per step (turni/ore/presenze dopo).
G. **Persistenza mock**: `localStorage` + pulsante "reset dati".
- Minori: niente i18n (solo IT hardcoded); icone Lucide per la chrome.

**Convenzione codice (utente, 2026-06-19 19:30; precisata 19:52):** identificatori,
commenti, nomi di endpoint/risorse, **path e nomi delle route** tutti in inglese
(es. `/volunteer/events`, route name `volunteer-events`). Restano in italiano SOLO
i testi mostrati all'utente (label, toast, copy) perché l'app è in lingua italiana
per LILT.

## Implementation Steps

Convenzione: `[x]` = fatto, `[ ]` = da fare.

- [x] [2026-06-19 18:59] [draft console-staff] Scaffolding iniziale frontend (config + store/seed bozza).
- [x] [2026-06-19 19:05] [start console-staff] **Dipendenze installate** (Vue3.5/Vite6.4/Tailwind4.3/Pinia/Router/Lucide/PWA + Vitest/test-utils/jsdom).
- [x] [2026-06-19 19:05] [start console-staff] **Service layer mock** `src/api/`: `mockDb.js` (seed→localStorage, reset, events/applicants REST-like) + `index.js` (facade swap mock/http).
- [x] [2026-06-19 19:20] [start console-staff] **(TDD) Spec store** con Vitest: 10 spec (transizioni stato evento, decisioni applicant, conteggi, fillPct). Red → green confermato.
- [x] [2026-06-19 19:20] [start console-staff] **Refactor `stores/staff.js`** ora usa `src/api/`; aggiunto `stores/session.js` (ruolo, default supporter). NB: toast NON estratto in `stores/ui.js` — resta nello store staff (vedi Notes).
- [x] [2026-06-19 19:24] [start console-staff] **Libreria UI** `src/components/ui/`: PhoneStatusBar, BottomNav (per-ruolo), Toast, BottomSheet, StatusChip, Avatar, ProgressBar, LucideIcon (+ icons registry tree-shaken).
- [x] [2026-06-19 19:24] [start console-staff] **AppShell + role switcher** (`App.vue` + `RoleSwitcher.vue`): UI per ruolo; switcher dev persistito; placeholder per supporter/volunteer.
- [x] [2026-06-19 19:24] [start console-staff] **EventsView** (frame 1): lista, filtri stato, card azioni Pubblica/Gestisci/Annulla, header brand.
- [x] [2026-06-19 19:24] [start console-staff] **Cancel sheet** (frame 3): BottomSheet causa annullamento sopra EventsView → cancelled + causa + toast.
- [x] [2026-06-19 19:24] [start console-staff] **CandidatureView** (frame 2): barra capienza, sezioni In attesa/Approvati/Riserva, azioni approve/waitlist/reject/move.
- [x] [2026-06-19 19:25] [start console-staff] **NewEventView** (frame 4): form completo con Salva bozza / Pubblica → createEvent.
- [x] [2026-06-19 19:26] [start console-staff] **PWA assets**: `favicon.svg` + `icon-192/512.png` (da SVG via ImageMagick); manifest generato in build.
- [x] [2026-06-19 19:27] [start console-staff] **Verifica finale**: `npm test` 10/10 verdi, `npm run build` ok (bundle 921KB→141KB dopo tree-shaking icone), dev server 200 + tutte le SFC compilano. README `frontend/` scritto.

## Risks

- **TDD vs velocità hackathon**: gli spec dello store aggiungono setup (Vitest). Tenerli minimali e mirati alla business logic (transizioni di stato), non alla UI. *Risolto 2026-06-19 19:00:* l'utente conferma di **tenere gli spec Vitest** (TDD-first sullo store).
- **Tailwind v4 "on the edge"**: API ancora in evoluzione; rischio di breaking minor. Mitigazione: pinnare la versione esatta installata.
- **Fedeltà al design vs PWA reale**: il mock disegna un telefono con status bar "9:41"; in PWA reale la status bar di sistema esiste già. Decisione E: colonna mobile centrata, status-bar finta solo come tocco estetico opzionale (no logica).
- **Interfaccia service layer**: va disegnata pensando già al backend Rails (risorse Event/Application/Person) per evitare rework allo swap.
- **Stato condiviso tra ruoli**: gli store devono restare neutri rispetto al ruolo; la differenziazione vive in shell/route/viste (decisione C).

## Context

- **Ticket**: nessuno (progetto hackathon, no Nosco ticket).
- **Branch**: `feat/console-staff-mock` (da `master`; non esistono `development`/`main`).
- **Design sorgente**: Design project "Stream di eventi PWA" (`4d15fa66-6651-400e-847c-cd1f33bf36de`), file `LILT - Staff.dc.html`. Esistono anche `LILT - Volontario` e `LILT - Simpatizzante` per gli step successivi.
- **Readme di progetto**: `Readme.md` (analisi dominio LILT: 3 attori, 2 pattern push/pull, privacy by design, consuntivo ore).
- **Decisioni A–G** concordate in chat il 2026-06-19 (vedi sezione "Decisioni di design concordate").
- **Memorie/note**: vivono dentro il progetto (vincolo CLAUDE.md globale dell'utente).

## Notes

- Questo è il **primo** di una serie di piani per step: dopo Staff seguiranno
  Volontario e Simpatizzante (riusando shell + UI lib + service layer), poi lo
  **switch a backend Rails** (sostituzione delle impl. in `src/api/`), e infine i
  domini mancanti (turni ricorrenti push, presenze, consuntivo ore).
- Niente login reale in questo piano: il ruolo si cambia via switcher dev.

### Deviazioni rispetto al piano iniziale (2026-06-19 19:27)
- **Toast non estratto in `stores/ui.js`**: resta nello store `staff` (è testato lì e
  funziona). L'estrazione in uno store `ui` condiviso è rimandata allo step multi-ruolo,
  quando anche Volontario/Supporter dovranno emettere toast.
- **Status bar finta** (`PhoneStatusBar`): tenuta come tocco estetico (decisione E),
  puramente cosmetica, da rivalutare per la PWA installata reale.
- **Bundle icone**: `import *` da lucide importava ~1000 icone (921KB); sostituito con
  registry esplicito `components/ui/icons.js` → 141KB. Aggiungere lì ogni nuova icona.
