# Plan: PWA — Installabilità completa

## Description

Portare la PWA da "tecnicamente installabile" (manifest minimo già presente) a
"installabile bene" su Android e iOS: icone maskable, meta tag Apple, screenshot
per la UI d'installazione ricca di Chrome, shortcut da long-press e un prompt di
installazione custom intercettando `beforeinstallprompt`.

È anche **prerequisito** del piano Web Push: su Safari iOS il push funziona solo
se la PWA è stata aggiunta alla schermata Home e gira in `display: standalone`.
Vedi `2026-06-20_pwa-web-push.md`.

## Goals

- Icona corretta nel launcher Android (maskable, niente quadratino bianco).
- Icona nitida in home su iOS + status bar coerente con il tema.
- UI d'installazione ricca su Chrome (anteprime via `screenshots`).
- Scorciatoie contestuali per ruolo (long-press sull'icona).
- Bottone "Installa app" mostrato dall'app al momento giusto, non il prompt di
  sistema casuale.

## Dependencies

- Nessuna nuova dipendenza npm: tutto passa per il manifest di `vite-plugin-pwa`
  (già in `frontend/vite.config.js`) e per `frontend/index.html`.
- Asset grafici da produrre: icona maskable 512px (con safe-zone ~80%),
  `apple-touch-icon` 180×180, 1-3 screenshot mobile.

## Initial Status

Lo stato attuale, dai file letti in questa sessione:

- **Manifest** in `frontend/vite.config.js:32-48` (plugin `VitePWA`):
  `name`, `short_name`, `description`, `theme_color: #0D9488`,
  `background_color: #E7E5DF`, `display: standalone`, `start_url: '/'`, e due
  icone PNG (`icon-192.png`, `icon-512.png`) **senza `purpose`** → nessuna
  maskable. Nessun `screenshots`, `shortcuts`, `categories`, `lang`, `id`.
- **Icone** in `frontend/public/`: `favicon.svg`, `icon-192.png`, `icon-512.png`.
  Nessun `apple-touch-icon`.
- **index.html** (`frontend/index.html`): ha già
  `<meta name="theme-color" content="#0D9488">` e
  `viewport-fit=cover` (buono per i notch), ma **mancano** i meta
  `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`,
  `apple-mobile-web-app-title` e il `<link rel="apple-touch-icon">`.
- **Route per gli shortcut** (da `frontend/src/router.js` / `App.vue:28`):
  home per ruolo `staff: /events`, `volunteer: /volunteer/events`,
  `supporter: /supporter/events`; creazione evento staff: `NewEventView`.
- **SW**: `registerType: 'autoUpdate'` → già genera e registra il service worker;
  l'installabilità di base è quindi già soddisfatta.

## Implementation Steps

TDD: in larga parte **non applicabile** — sono modifiche a manifest, meta tag e
asset statici (vedi `## Notes`). L'unica logica testabile è la gestione di
`beforeinstallprompt` (step 6).

- [x] [2026-06-20 02:38] [PWA enhancement] Analisi del codice esistente (manifest, index.html, icone, route).
- [x] [2026-06-20 04:30] [make PWA installable] Asset prodotti via ImageMagick in `frontend/public/`: `icon-512-maskable.png` (shield nel safe-zone 80%, full-bleed teal), `apple-touch-icon.png` (180×180, full-bleed opaco), `screenshot-1.png` + `screenshot-2.png` (1080×1920, narrow, placeholder brandizzati).
- [x] [2026-06-20 04:30] [make PWA installable] `frontend/vite.config.js`: manifest ampliato con `lang: 'it'`, `id: '/'`, `categories`, `icons` con voce maskable, `screenshots` (form_factor narrow, label).
- [x] [2026-06-20 04:30] [make PWA installable] `frontend/vite.config.js`: `manifest.shortcuts` → "Eventi" `/events`, "Nuovo evento" `/events/new`, "Le mie candidature" `/volunteer/applications` (globali, auto-protetti via `meta.role`).
- [x] [2026-06-20 04:30] [make PWA installable] `frontend/index.html`: meta Apple (`apple-mobile-web-app-capable`, `-status-bar-style=default`, `-title=LILT Staff`) e `<link rel="apple-touch-icon">`.
- [x] [2026-06-20 04:30] [make PWA installable] Custom install: store Pinia `stores/pwa.js` (cattura `beforeinstallprompt`, `canInstall`/`showInstallButton`, `arm()`, `promptInstall()`, gestione `appinstalled`/standalone/dismiss); `stores/pwa.spec.js` (10 test, mock dell'evento). `arm()` chiamato in `volunteer.applyAsVolunteer` (prima candidatura). Banner `components/ui/InstallPrompt.vue` montato in `App.vue`. `main.js` chiama `usePwaStore().init()` prima del mount.
- [x] [2026-06-20 04:30] [make PWA installable] `npm run build` OK: `dist/manifest.webmanifest` completo, tutti gli asset in `dist/`, meta Apple presenti in `dist/index.html`. Suite vitest verde (65 test).
- [ ] [2026-06-20 04:30] [make PWA installable] **Verifica manuale ancora da fare** (richiede browser/device reali): Chrome DevTools → Application → Manifest (no warning) + Lighthouse PWA; installazione reale su Android (icona maskable, shortcut) e iOS (Aggiungi a Home, standalone, status bar).

## Risks

- **Asset grafici**: la maskable senza safe-zone corretta viene tagliata; gli
  screenshot con dimensioni sbagliate fanno fallire la UI ricca di Chrome.
- **Cache del manifest**: dopo il deploy il vecchio manifest può restare in cache;
  in test usare hard-reload / disinstallare e reinstallare la PWA.
- **iOS**: niente install prompt programmatico (`beforeinstallprompt` è solo
  Chromium); su iOS l'utente deve usare "Aggiungi a schermata Home" → eventuale
  micro-istruzione nella UI.
- **Open question** [RISOLTA 2026-06-20, sessione "make PWA installable"]:
  - Set di shortcut confermato (tutti e tre, globali): **Eventi → `/events`**,
    **Nuovo evento → `/events/new`**, **Le mie candidature → `/volunteer/applications`**.
  - Trigger del prompt custom: **dopo un'azione chiave** (la prima candidatura
    volontario, `applyAsVolunteer`), non subito. Nascosto se già in standalone o
    se `beforeinstallprompt` non è disponibile (iOS).

## Context

- **Ticket**: nessuno (iniziativa interna, hackathon).
- Origine: brainstorming PWA, filone #1. Sessione "PWA enhancement".
- Piani collegati: `2026-06-20_pwa-web-push.md` (dipende da questo su iOS),
  `2026-06-20_pwa-toast-nuova-versione.md`.

## Notes

- TDD saltato per manifest/meta/asset: sono configurazione e file statici, non
  logica di business (in linea con la regola del template). Spec previste solo
  per il composable di `beforeinstallprompt`.
- Stack PWA: `vite-plugin-pwa` 0.21 (Workbox sotto). Tutto il manifest è
  centralizzato nel plugin, non serve un `manifest.webmanifest` a mano.
- [2026-06-20, "make PWA installable"] Branch base: il repo non ha `development`;
  feature branch tagliato da `main` → `feat/pwa-installabilita-completa`.
- [2026-06-20, "make PWA installable"] Asset: icone generate via ImageMagick a
  partire dalla SVG dello scudo (full-bleed teal, safe-zone 80% per la maskable;
  full-bleed senza arrotondamenti per `apple-touch-icon`, così iOS arrotonda da
  solo). Gli **screenshot** sono placeholder brandizzati (palette app) per
  rendere valida la UI ricca di Chrome: **da sostituire con catture reali**
  prima della pubblicazione pubblica.
