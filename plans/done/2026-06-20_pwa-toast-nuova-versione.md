# Plan: PWA — Toast "nuova versione disponibile"

## Description

Sostituire l'aggiornamento silenzioso del service worker (`autoUpdate`) con un
flusso controllato: quando è disponibile una nuova versione, mostrare un Toast
"Aggiorna" che, al tap, attiva il nuovo SW e ricarica. Evita che l'utente resti
con asset disallineati senza saperlo e dà una percezione di qualità alta a costo
basso. Riusa il componente `Toast` e lo store `ui` già presenti.

## Goals

- Rilevare `needRefresh` quando un nuovo SW è in waiting.
- Mostrare un Toast con azione "Aggiorna" (non un auto-reload a sorpresa).
- Al tap: `updateServiceWorker(true)` → skipWaiting + reload.
- (Opzionale) Toast informativo "Pronta per l'uso offline" al primo cache.

## Dependencies

- Nessuna nuova dipendenza: `vite-plugin-pwa` espone l'helper
  `virtual:pwa-register/vue` (`useRegisterSW`) che dà `needRefresh`,
  `offlineReady` e `updateServiceWorker()`.
- **Coordinamento con il piano Web Push**: se si passa a `injectManifest` per il
  SW custom (push handler), questo flusso va riadattato ma il concetto resta. Va
  deciso insieme. Vedi `2026-06-20_pwa-web-push.md`.

## Initial Status

- **SW**: `registerType: 'autoUpdate'` in `frontend/vite.config.js` → il SW si
  aggiorna in modo silenzioso, senza UI di consenso. (Stato pre-intervento.)
- **Registrazione**: nessuna registrazione manuale; `frontend/src/main.js` monta
  solo l'app, il plugin inietta la registrazione del SW.
- **Toast esistente**: `frontend/src/components/ui/Toast.vue` legge `ui.toast`
  (`{ text, tone }`) dallo store `frontend/src/stores/ui.js`. Lo store ha
  `showToast(text, tone)` con **auto-dismiss a 3s** e
  `clearToast()`. Toni disponibili: `ok`, `publish`, `info`, `danger`. Il
  componente **non** ha un'azione/bottone, solo icona + testo.
- `<Toast />` è montato una sola volta in `frontend/src/App.vue`.

## Implementation Steps

TDD: in larga parte **non applicabile** — il cuore è l'integrazione col modulo
virtuale `virtual:pwa-register/vue`, difficile da unit-testare senza mock pesanti
e con poco valore. L'estensione dello store `ui` con un toast "azionabile" è
invece testabile (step 1).

- [x] [2026-06-20 02:38] [PWA enhancement] Analisi: confermato `autoUpdate`, assenza di registrazione manuale, e che `Toast`/`ui` store non supportano azioni né durata infinita.
- [x] [2026-06-20 11:16] [toast update] Decisione `registerType`: **`'prompt'`** (confermato dall'utente via AskUserQuestion). Sovrascrive la nota del piano Web Push ("si mantiene autoUpdate"): con `injectManifest` + `prompt`, il SW custom NON fa più `skipWaiting()` incondizionato — aspetta il messaggio `SKIP_WAITING`. `vite.config.js` → `registerType: 'prompt'`.
- [x] [2026-06-20 11:16] [toast update] (TDD) Esteso store `ui` (`frontend/src/stores/ui.js`): nuova action `showActionToast(text, tone, action)` con `action = { label, run }`, **senza** auto-dismiss e che annulla il timer 3s pendente. Spec `frontend/src/stores/ui.spec.js` (5 test) verde.
- [x] [2026-06-20 11:16] [toast update] `frontend/src/components/ui/Toast.vue`: bottone azione renderizzato quando `toast.action` è presente; al click `clearToast()` + `action.run()`.
- [x] [2026-06-20 11:16] [toast update] Composable `frontend/src/composables/useAppUpdate.js` con `useRegisterSW` da `virtual:pwa-register/vue`; su `needRefresh` → `showActionToast('Nuova versione disponibile', 'info', { label: 'Aggiorna', run: () => updateServiceWorker(true) })`. Montato in `App.vue` setup. SW (`frontend/src/sw.js`): rimosso `self.skipWaiting()` incondizionato, aggiunto listener `message` su `SKIP_WAITING`; `clientsClaim()` mantenuto.
- [x] [2026-06-20 11:16] [toast update] (Opzionale, incluso) Su `offlineReady` → `ui.showToast("App pronta per l'uso offline", 'info')` (auto-dismiss normale).
- [x] [2026-06-20 11:16] [toast update] Verifica build: `npx vitest run` 77/77 verdi; `npm run build` OK (mode injectManifest, 9 precache). `dist/sw.js`: 1 sola occorrenza di `skipWaiting` (nel guard), `SKIP_WAITING` presente, handler `push`/`notificationclick` preservati.
- [ ] [2026-06-20 11:16] [toast update] **(Non bloccante — verifica manuale rimandata all'uso reale)** Su device/`npm run preview`: build → preview, poi secondo build con una modifica, ricaricare e controllare che compaia il Toast "Aggiorna", che il tap attivi il nuovo SW e ricarichi, e che senza aggiornamenti non compaia nulla. (HMR di `vite dev` confonde il ciclo SW — testare in preview/prod, mai in dev.)

## Risks

- **Conflitto con Web Push / SW custom** [RISOLTO 2026-06-20, sessione "toast update"]:
  il piano Web Push è già passato a `injectManifest` con SW custom (`frontend/src/sw.js`).
  `useRegisterSW` (da `virtual:pwa-register/vue`) funziona nello stesso contesto; il
  SW custom ora fa `skipWaiting()` solo on-demand. Scelta SW allineata: **`prompt`**.
- **Toast persistente**: oggi tutti i toast si auto-chiudono a 3s; il toast
  d'aggiornamento deve restare finché l'utente non agisce o cambia route — non
  rompere il comportamento degli altri toast.
- **UX del reload**: `updateServiceWorker(true)` ricarica la pagina; assicurarsi
  di non perdere stato non salvato (qui basso rischio, dati vivono lato API).
- **Loop di update** in dev: testare in `preview`/produzione, non in `vite dev`
  (HMR confonde il ciclo del SW).

## Context

- **Ticket**: nessuno (iniziativa interna, hackathon).
- Sviluppato su un branch feature poi mergiato in `main` (fast-forward).
- Origine: brainstorming PWA, filone #3. Sessione "PWA enhancement".
- Piani collegati: `2026-06-20_pwa-web-push.md` (scelta SW condivisa),
  `2026-06-20_pwa-installabilita-completa.md`.

## Notes

- È il filone a sforzo più basso e va fatto idealmente **prima o insieme** alla
  scelta della strategia SW del piano Web Push, così si decide una volta sola se
  il SW resta generato o diventa custom.
- Riuso massimo: `Toast.vue` + store `ui` già esistono; serve solo renderli
  "azionabili" e senza auto-dismiss per questo caso.
