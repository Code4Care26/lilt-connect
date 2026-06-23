# Plan: Badge di ingaggio volontario sulla card evento

## Description

Il ruolo **volontario** deve avere un "ingaggio" sull'evento: la card evento (e il
dettaglio) deve dare evidenza al volontario quando **non è ancora stato raggiunto
il numero minimo di partecipanti**, così da motivarlo a candidarsi. La richiesta si
concretizza in un **badge** sulla card che mostra quanti volontari mancano ancora.

Coerentemente con l'architettura del progetto (il backend è l'unica fonte di
verità: `Event#as_api` deriva già `applicationsCount`/`waitlistCount` dai dati reali),
il calcolo "minimo raggiunto?" vive **nel backend** e viaggia nel contratto JSON; il
frontend si limita a renderizzare il badge con la sua palette/etichetta.

## Goals

- Il volontario vede sulla card dello stream e nella pagina di dettaglio un badge
  "ingaggio" quando l'evento **non ha ancora raggiunto il numero minimo di
  partecipanti**, con il numero di volontari ancora mancanti.
- Quando il minimo è raggiunto (o l'evento non è `published`), il badge **non**
  compare.
- Nessuna nuova persistenza / migration: il minimo è **derivato dagli slot**.
- Il valore di "ingaggio" è calcolato lato backend e incluso nel contratto, così il
  frontend non duplica la logica di soglia.
- L'aggiornamento è coerente col realtime SSE già presente: il badge si ri-deriva
  ad ogni `load()` (le candidature che cambiano emettono già `applications.changed`).

## Dependencies

- Stack attuale: Rails 8 API-only + Vue 3 / Pinia. Nessuna gemma o pacchetto nuovo.
- Contratto evento esistente (`Event#as_api`) e store `volunteer` (`decorate`).
- Icone Lucide già disponibili lato frontend (`components/ui/icons.js`) per il badge.

## Initial Status

Stato attuale rilevato in sessione (2026-06-19). **Non esiste oggi** alcun concetto
di "numero minimo di partecipanti": gli eventi portano solo
`slots: { approved, available }` e i conteggi vivi delle candidature. L'evento seed
`e5` è `cancelled` con `reason: "Adesioni insufficienti"` — proprio il caso che questa
feature formalizza preventivamente.

### Decisioni di scope (confermate dall'utente in questa sessione)

- **Cosa conta verso il minimo** → *candidature attive*, già esposte come
  `applicationsCount` (`Event::CANDIDATURE_STATUSES` = pending + approved + waitlist;
  supporter e withdrawn esclusi).
- **Sorgente del minimo** → *derivato dagli slot*, nessun nuovo campo / migration:
  `minParticipants = slots["approved"] + slots["available"]` (capienza piena dell'evento).
- **Dove mostrare il badge** → *stream volontario + dettaglio volontario*.

Definizione operativa risultante:
- `minParticipants = slots.approved + slots.available`
- `missingParticipants = max(0, minParticipants - applicationsCount)`
- `needsParticipants = (status == "published") && missingParticipants > 0`

### File rilevanti

**Backend (fonte di verità)**
- `backend/app/models/event.rb` — `Event#as_api` (le 3 chiavi derivate + helper
  `min_participants_value`); `CANDIDATURE_STATUSES` (allineato a "candidature attive").
- `backend/test/integration/api/events_test.rb` — `EVENT_KEYS` e i test del contratto.

**Frontend (presentazione)**
- `frontend/src/data/meta.js` — `VOLUNTEER_ENGAGEMENT_META`: metadata del badge di
  ingaggio (etichetta/colori/icona), separato dallo status chip.
- `frontend/src/stores/volunteer.js` — getter `decorate`: costruisce `engagement`
  quando il backend segnala `needsParticipants`.
- `frontend/src/views/VolunteerStreamView.vue` — la card: badge sotto lo status `chip`.
- `frontend/src/views/VolunteerEventDetailView.vue` — blocco "Cerchiamo volontari":
  badge sotto la riga `slots.approved / slots.available`.
- `frontend/src/views/NewEventView.vue` — `save()`: invia gli slot
  (`{ approved: 0, available: volontari richiesti }`) così il minimo è valorizzato.

**Test**
- `backend/test/integration/api/events_test.rb` — request spec del contratto.
- `frontend/src/stores/volunteer.spec.js` — spec del getter `decorate`.
- `frontend/src/test/fakeApi.js` — fake usato dagli spec store (verificare che esponga
  le nuove chiavi derivate, o che il calcolo resti lato store se il fake non le porta —
  vedi Risks).

## Implementation Steps

These steps will be updated as the plan progresses. Convention: `[x]` = done, `[ ]` = pending.

- [x] [2026-06-19 23:29] [DRAFT engagement-badge] Analisi codebase e definizione contratto/derivazione (questo documento).

### Backend (TDD-first)

- [x] [2026-06-19 23:43] [IMPL engagement-badge] In `backend/test/integration/api/events_test.rb`: esteso `EVENT_KEYS` con `minParticipants`, `missingParticipants`, `needsParticipants` + 2 test (sotto/al minimo per `e1` via `EventApplication`; `e5` cancelled → `needsParticipants==false`). Rosso confermato prima dell'implementazione.
- [x] [2026-06-19 23:43] [IMPL engagement-badge] In `backend/app/models/event.rb` `as_api`: aggiunte le chiavi derivate + helper privato `min_participants_value` (`approved + available`); `missingParticipants = max(min - applicationsCount, 0)`; `needsParticipants = status == "published" && missing.positive?`. Verde.

### Frontend (TDD-first)

- [x] [2026-06-19 23:44] [IMPL engagement-badge] In `frontend/src/stores/volunteer.spec.js`: spec rosso per `engagement` (badge presente con label che cita il mancante su `e1`; `null` su `e3` al minimo e `e5` cancelled; `null` per evento "bare"). Allineato `frontend/src/test/fakeApi.js` con le 3 nuove chiavi su tutti gli eventi fixture.
- [x] [2026-06-19 23:44] [IMPL engagement-badge] In `frontend/src/data/meta.js`: aggiunto `VOLUNTEER_ENGAGEMENT_META` (tono ambra come `Posti limitati`, icona `UserPlus`, `label(missing)` con singolare/plurale). Registrata l'icona `UserPlus` in `frontend/src/components/ui/icons.js`.
- [x] [2026-06-19 23:44] [IMPL engagement-badge] In `frontend/src/stores/volunteer.js` getter `decorate`: costruito `engagement` da `needsParticipants`/`missingParticipants` del backend; `null` altrimenti. Verde.
- [x] [2026-06-19 23:44] [IMPL engagement-badge] In `frontend/src/views/VolunteerStreamView.vue`: badge `ev.engagement` reso sotto lo status chip (`v-if`).
- [x] [2026-06-19 23:44] [IMPL engagement-badge] In `frontend/src/views/VolunteerEventDetailView.vue`: stesso badge nel blocco "Cerchiamo volontari", sotto la riga slots.

### Verifica

- [x] [2026-06-19 23:44] [IMPL engagement-badge] `bin/rails test` (33 runs) e `npx vitest run` (52 test) verdi.
- [x] [2026-06-20 00:05] [IMPL engagement-badge] Fix collegato emerso in verifica: il form "Nuovo evento" (`NewEventView.vue`) non inviava i "Volontari richiesti", quindi gli eventi nascevano con `slots {0,0}` (min 0, nessun badge). `save()` ora invia `slots: { approved: 0, available: volunteers }`. Aggiunto test backend `POST /api/events with slots`. Verifica end-to-end sul server live OK: evento pubblicato con 5 volontari richiesti mostra il badge in lista e in dettaglio.

## Risks

- **Semantica "minimo = capienza piena"**: derivando `min = approved + available`, il
  minimo coincide con la capienza totale; finché ci sono posti disponibili il badge
  resta acceso. È coerente con la scelta "derivato dagli slot", ma se in futuro si
  vorrà una soglia minima < capienza servirà un campo dedicato (out of scope qui).
- **Conteggi vivi vs colonne seed**: `applicationsCount` è calcolato dalle righe
  `EventApplication` reali, non dalla colonna `applications_count`. Dopo un `Seeds.run!`
  non esistono candidature seedate → `applicationsCount == 0` per tutti, quindi il badge
  comparirà su tutti gli eventi `published` fino alle prime adesioni reali. Atteso e
  desiderabile per la demo, ma da segnalare in verifica.
- **Disallineamento fake frontend**: `frontend/src/test/fakeApi.js` ha un proprio seed
  (lo spec store si aspetta e1 approved, e2 pending, ecc.) che NON coincide col seed
  backend. Verificare che il fake esponga le nuove chiavi derivate; in alternativa il
  badge potrebbe essere derivato interamente nel getter `decorate` a partire da `slots`
  + `applicationsCount` (entrambi già nel contratto), evitando dipendenza dalle nuove
  chiavi — decisione da prendere allo step frontend.
- **Drift del contratto**: `EVENT_KEYS` in `events_test.rb` asserisce l'insieme esatto
  delle chiavi; dimenticare di aggiornarlo fa fallire i test (comportamento voluto).

## Context

- **Ticket**: nessuno (richiesta diretta dell'utente in sessione).
- **Branch**: `feat/volunteer-engagement-badge`, creato da `main` dopo il merge
  fast-forward di `feat/sse-realtime` in `main` (2026-06-19 23:29).
- Architettura: backend = unica fonte di verità (vedi `Identity`, `Event#as_api`);
  il frontend è "backend-only" e renderizza il contratto. Realtime SSE già presente
  (`Realtime`, `Api::StreamController`): i cambi candidatura emettono `applications.changed`.

## Notes

- TDD-first applicato sia al backend (request spec del contratto) sia al frontend
  (spec del getter `decorate`): entrambi sono business logic non banale con coverage
  esistente da estendere.
- Il badge di "ingaggio" è un visual **distinto** dallo status `chip` del volontario
  (`VOLUNTEER_APP_META`): il chip riflette lo stato della *sua* candidatura, il badge
  riflette il fabbisogno di *staffing* dell'evento. Possono coesistere sulla stessa card.
- Naming chiavi contratto adottato: `minParticipants`, `missingParticipants`,
  `needsParticipants`.
- Gli eventi creati **prima** del fix del form restano con `slots {0,0}` (min 0) e
  non mostrano il badge: vanno ricreati o resettati ai seed (`POST /api/reset`).
- Etichetta del pulsante di rinuncia volontario semplificata in sessione:
  "Tira pacco · rinuncia" → "Rinuncia" (lista) / "Rinuncia all'evento" (dettaglio).
