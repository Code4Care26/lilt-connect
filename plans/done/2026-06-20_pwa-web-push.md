# Plan: PWA — Web Push end-to-end

## Description

Aggiungere le notifiche push a app **chiusa/background** (Web Push + VAPID),
complementari all'SSE esistente (che copre solo il foreground). Caso d'uso di
dominio: avvisare il volontario quando la sua candidatura cambia stato
("candidatura accettata"), quando un evento viene cancellato/modificato, o quando
esce un nuovo turno. Tocca tre servizi: Vue (frontend) → Rails (mittente + DB
subscription) → il SW gestisce `push`/`notificationclick`.

## Goals

- L'utente può concedere il permesso notifiche e iscriversi al push.
- La `PushSubscription` è persistita lato Rails, legata all'identity corrente.
- Quando un evento di dominio cambia, Rails invia un push cifrato (VAPID).
- Tap sulla notifica → apre l'app sul route giusto; la fetch REST porta lo stato
  fresco (coerente col modello a invalidazioni dell'SSE).
- Subscription ripulita al logout.

## Dependencies

- **Prerequisito iOS**: `2026-06-20_pwa-installabilita-completa.md` — su Safari
  iOS 16.4+ il push richiede PWA installata in `display: standalone`.
- **Frontend**: nessuna libreria nuova (Push API + `pushManager` nativi). Serve
  però accedere alla registrazione del SW; con `vite-plugin-pwa` si usa
  `virtual:pwa-register` / `navigator.serviceWorker.ready`.
- **Backend Rails**: gem `web-push` (gestisce VAPID + cifratura del payload).
  Generare una coppia di chiavi VAPID (la pubblica va anche al frontend).
- **Service worker**: passaggio a `strategies: 'injectManifest'` (deciso — vedi
  Risks). SW custom in `frontend/src/sw.js` con `precacheAndRoute(self.__WB_MANIFEST)`
  + handler `push`/`notificationclick`. Si mantiene `registerType: 'autoUpdate'`.

## Initial Status

- **SSE** (`frontend/src/api/stream.js`, `App.vue`): EventSource su
  `/sse/stream?identity=…`, porta solo messaggi di invalidazione; l'app rifà la
  fetch REST. Funziona solo a tab aperta. Il push è il canale complementare per
  il background. L'identity viaggia in querystring perché EventSource non manda
  header custom.
- **Identity** (mock): header `X-Identity-Id` impostato da
  `frontend/src/api/http.js` (`setIdentity`), risolto a ruolo lato Rails in
  `backend/app/controllers/api/base_controller.rb` via `Identity.role_for`.
  Logout in `frontend/src/stores/session.js` azzera l'identity.
- **API client**: `frontend/src/api/http.js` (oggetto `httpApi`) +
  `frontend/src/api/index.js` (`api`). Nuovi endpoint push vanno aggiunti qui.
- **Backend**: Rails con namespace `:api` (`backend/config/routes.rb`),
  controller in `backend/app/controllers/api/`, modelli in
  `backend/app/models/` (`event`, `event_application`, `participation`).
  **Nessuna** gem push presente (verificato sul Gemfile).
- **Fan-out realtime**: `gosse` (Go) + Redis pub/sub già instradano le
  invalidazioni; il push è un canale separato, inviato da Rails.

## Implementation Steps

TDD-first dove c'è logica: la persistenza/lookup delle subscription e l'invio
push lato Rails sono testabili con spec (mockando la consegna `WebPush`). Il SW e
la UI di permesso si verificano manualmente sul device.

- [x] [2026-06-20 02:38] [PWA enhancement] Analisi: mappato SSE, identity/X-Identity-Id, API client, routes e modelli Rails; confermata assenza di gem push.
- [x] [2026-06-20 10:05] [start web push] Risolte le due open question (SW: `injectManifest`; mittente push: Rails). Piano mosso in `in-progress/`, branch `feat/pwa-web-push` da `main`.
- [x] [2026-06-20 10:05] [start web push] Backend: gem `web-push` (~> 3.1) nel Gemfile; chiavi VAPID via ENV (`VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY`/`VAPID_SUBJECT`) in `backend/.env` gitignored, sourced da `run.sh` e `Procfile.dev`. Chiave pubblica esposta via `GET /api/push/vapid_public_key`.
- [x] [2026-06-20 10:05] [start web push] Backend (TDD): modello `PushSubscription` (`identity_id`/`endpoint`/`p256dh`/`auth`; unique su `endpoint`; scope `for_identity`) + migrazione. Test `test/models/push_subscription_test.rb` verde.
- [x] [2026-06-20 10:05] [start web push] Backend (TDD): `Api::PushSubscriptionsController` con `POST` (upsert per endpoint, ri-bind all'identity corrente), `DELETE` (cleanup scoped per identity) e `GET vapid_public_key`. Route nel namespace `:api`. Identity richiesta (blank → 422). Test integrazione verde.
- [x] [2026-06-20 10:05] [start web push] Backend (TDD): servizio `PushNotifier` (specchio di `Realtime`: transport sostituibile, no-op senza VAPID, best-effort). Invia via `WebPush.payload_send`, prune su `ExpiredSubscription`/`InvalidSubscription` (404/410), errori transienti ingoiati senza prune. Test verde.
- [x] [2026-06-20 10:05] [start web push] Backend: hook in `EventApplication` `after_commit on: [:create, :update]` → `notify_volunteer_if_approved`, gated su `saved_change_to_status? && status == 'approved'`. Notifica il volontario sullo stesso commit dell'invalidazione SSE. Test `event_application_push_test.rb` verde.
- [x] [2026-06-20 10:05] [start web push] Frontend: `api.push.vapidKey/subscribe/unsubscribe` in `frontend/src/api/http.js`.
- [x] [2026-06-20 10:05] [start web push] Frontend (TDD): store `usePush` (`supported`/`permission`/`subscribed`/`busy`, `denied`/`canPrompt`, `refresh`/`enablePush`/`disablePush`, helper `urlBase64ToUint8Array`). Spec `stores/push.spec.js` (7 test) mockando `Notification`/`serviceWorker`/`pushManager`/`api`.
- [x] [2026-06-20 10:05] [start web push] Frontend: `session.logout()` ora async → chiama `usePushStore().disablePush()` PRIMA di azzerare l'identity (la DELETE su Rails è scoped per identity). `switchUser()` in `VolunteerProfileView` awaita.
- [x] [2026-06-20 10:05] [start web push] Service worker (`injectManifest`): `frontend/src/sw.js` (`precacheAndRoute(self.__WB_MANIFEST)` + `skipWaiting`/`clientsClaim` per parità autoUpdate + handler `push`/`notificationclick`). `vite.config.js` su `strategies: 'injectManifest'`, `srcDir: 'src'`, `filename: 'sw.js'`. `npm run build` OK (mode injectManifest, 9 precache entries, handler presenti in `dist/sw.js`).
- [x] [2026-06-20 10:05] [start web push] UI: card "Notifiche push" in `VolunteerProfileView.vue` (toggle Attiva/Disattiva, gesto utente, feedback via Toast, `push.refresh()` on mount senza prompt). Icona `BellOff` aggiunta a `icons.js`. Visibile solo se `push.supported`.
- [x] [2026-06-20 10:05] [start web push] Deploy (kapsule): VAPID nel Secret k8s. `04-secrets.sh` richiede `VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY` (pattern `:?`) + `VAPID_SUBJECT` (default `mailto:$ACME_EMAIL`), aggiunte come `--from-literal` (`vapid-public-key`/`-private-key`/`-subject`). `k8s/backend.yaml`: tre env via `secretKeyRef` (non nel migrate-job: le migrazioni non inviano push). bash/yaml lint OK.
- [ ] [2026-06-20 10:05] [start web push] **(Non bloccante — verifica manuale rimandata all'uso reale)** Verifica end-to-end su device reale (Android Chrome e iPhone con PWA installata): permesso → subscribe → cambio stato candidatura da staff → notifica a app chiusa → tap → route corretto. Richiede VAPID keys nel `.env` (dev) / Secret (prod) e i tre servizi up.

## Risks

- **Service worker custom + autoUpdate** [RISOLTO 2026-06-20, sessione "start web push"]:
  oggi il SW è interamente generato (`registerType: 'autoUpdate'`). Scelta fissata:
  **`strategies: 'injectManifest'`** — SW scritto a mano (`frontend/src/sw.js`) con
  `precacheAndRoute(self.__WB_MANIFEST)` + handler `push`/`notificationclick`. Si
  mantiene `registerType: 'autoUpdate'`. La stessa scelta serve anche al piano
  Toast/aggiornamento (`2026-06-20_pwa-toast-nuova-versione.md`), che condivide il SW.
- **iOS**: push solo se PWA installata e standalone (dipendenza dal piano
  installabilità); requisiti più stretti e debugging più scomodo.
- **Identity mock**: la subscription è per-device ma legata a un'identity
  free-form; cambio nome = subscription orfana. Per l'hackathon accettabile, ma
  va gestito il cleanup al logout (step dedicato).
- **Chiavi VAPID e segreti**: non committare la chiave privata; gestire via
  credentials/ENV. La pubblica può stare nel client.
- **Permessi negati / revocati**: gestire `permission === 'denied'` senza loop di
  richieste; degradare silenziosamente all'SSE.
- **Open question** [RISOLTA 2026-06-20, sessione "start web push"]: mittente
  canonico del push = **Rails** (ha business logic + DB subscription); gosse resta
  solo invalidazioni SSE. Nessuna chiave VAPID né accesso al DB subscription in gosse.

## Context

- **Ticket**: nessuno (iniziativa interna, hackathon).
- Sviluppato su un branch feature poi mergiato in `main`.
- Origine: brainstorming PWA, filone #2. Sessione "PWA enhancement".
- Piani collegati: `2026-06-20_pwa-installabilita-completa.md` (prerequisito iOS),
  `2026-06-20_pwa-toast-nuova-versione.md` (entrambi toccano la strategia SW).

## Notes

- SSE vs Push: complementari, non alternativi. Foreground → SSE (re-fetch su
  invalidazione); background/app chiusa → Push. Possibile evoluzione: chiudere
  l'SSE su `visibilitychange` quando la tab è nascosta.
- Il payload del push dovrebbe restare "magro" e coerente col modello a
  invalidazioni: notifica con titolo/url, e al tap l'app rifà la fetch REST.
- [2026-06-20, "start web push"] **Consegna sincrona** nel hook `after_commit`:
  `PushNotifier.notify` invia inline (non in un thread detached come `Realtime`).
  È best-effort (ingoia tutti gli errori → non fa mai fallire la mutation) ma
  aggiunge latenza alla `update!` di approvazione (1-pochi `WebPush.payload_send`
  HTTP). Accettabile per l'hackathon (azione staff, bassa frequenza). **Evoluzione**:
  spostare su ActiveJob quando ci sarà un'infrastruttura di code, per non bloccare
  il thread di richiesta.
- [2026-06-20, "start web push"] Config VAPID via ENV (coerente con il resto
  dell'app: DB, `SSE_PUBLISH_*`). Niente dotenv nel progetto → `backend/.env`
  (gitignored da `backend/.env*` nel root `.gitignore`) viene sourced in `run.sh`
  e nella riga `rails` del `Procfile.dev` con `set -a; . ./.env; set +a`. La chiave
  privata NON è committata. Per il deploy kapsule andranno settate le ENV VAPID.
- [2026-06-20, "start web push"] SW su `injectManifest`: questo è anche il
  prerequisito del piano Toast/aggiornamento, che ora può scrivere il suo
  prompt-update nello stesso `frontend/src/sw.js`.
- [2026-06-20, "toast update"] **`registerType` cambiato `autoUpdate` → `prompt`**
  dal piano Toast (`2026-06-20_pwa-toast-nuova-versione.md`). Il SW custom non fa
  più `skipWaiting()` incondizionato: ora attiva il nuovo SW solo su messaggio
  `SKIP_WAITING` (tap dell'utente sul toast "Aggiorna"). Il push NON è impattato:
  gli handler `push`/`notificationclick` restano nel SW e il SW vecchio continua
  a gestire i push finché l'utente non aggiorna. `clientsClaim()` mantenuto.
- [2026-06-20, "start web push"] Test: backend 63 runs verdi (18 nuovi),
  frontend 72 verdi (7 nuovi), `npm run build` OK. Manca solo la verifica E2E su
  device reale (ultimo step).
- [2026-06-20, "start web push"] **Deploy / implicazioni** (kapsule):
  - HTTPS già presente (prereq secure-context) ✅; migrazione `push_subscriptions`
    automatica via `migrate-job` (`db:prepare`) ✅; caching `/sw.js` già `no-cache`
    in `frontend/nginx.conf` ✅ (ho mantenuto il filename `sw.js`).
  - **Chiave pubblica al FE a runtime** (`GET /api/push/vapid_public_key`), non a
    build-time → ruotare/configurare le chiavi NON richiede rebuild del frontend.
  - **Rebuild frontend necessario** comunque per il nuovo `dist/sw.js` (da SW
    generato a custom): `03-build-push.sh` + `07-aggiorna.sh`.
  - **Keypair VAPID stabile**: generare UNA volta, conservare nel secret manager
    del team; rigenerarlo invalida tutte le subscription già nei browser.
  - Al prossimo deploy: esportare `VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY` prima di
    `./04-secrets.sh` (come `PG_PASSWORD` ecc.), poi `./05-deploy.sh`.
