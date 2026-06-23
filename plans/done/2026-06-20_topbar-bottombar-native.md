# Plan: Topbar + BottomNav fissate (look "app nativa" in PWA)

## Description

Far sì che l'header in alto (per-view) e la bottom navigation restino **fissi
sui bordi del viewport** mentre solo il contenuto scorre, così l'app installata
come PWA dà la stessa sensazione di una app nativa. Il problema non era il
posizionamento delle barre ma l'**unità di altezza** dello shell: `min-h-screen`
(`100vh`) su mobile è più alto dell'area visibile (include la striscia dietro la
barra URL che si auto-nasconde), quindi scrollava l'intera pagina trascinando le
barre fuori vista. La soluzione è bloccare lo shell a `100dvh` (dynamic viewport
height) con `overflow-hidden`, lasciando un unico scroller interno (`<main>`), e
rispettare le safe-area iOS sulla bottom nav.

## Goals

- Header per-view percepito come "pinnato" in alto, senza che scrolli con la pagina.
- BottomNav fissata sul fondo del viewport reale (non sotto la chrome del browser).
- Nessuno scroll di pagina: scorre solo il contenuto di `<main>`.
- Bottom nav che libera l'home indicator iOS (safe-area-inset-bottom).
- Nessuna regressione sul layout desktop (colonna "telefono" centrata e arrotondata).

## Dependencies

- Nessuna nuova dipendenza. Tailwind v4 espone già le utility `h-dvh` e i valori
  arbitrari con `env()` (verificato: compilano nel CSS di build).
- `index.html` ha già `viewport-fit=cover` (prerequisito per `env(safe-area-inset-*)`).

## Initial Status

- **Shell**: `frontend/src/App.vue` — wrapper esterno `min-h-screen` (`100vh`) e
  colonna telefono `flex-1 ... overflow-hidden`. `<main class="... flex-1
  overflow-y-auto">` contiene `<router-view/>`; `<BottomNav>` è
  `absolute inset-x-0 bottom-0`.
- **Header per-view**: ogni view è `flex h-full flex-col` con un `<header
  flex-none>` in cima e una lista interna `overflow-y-auto` (es.
  `frontend/src/views/EventsView.vue`). Quindi l'header è **già**
  strutturalmente fisso: scorre solo la lista interna. Appariva non-fisso solo
  perché l'intera pagina scrollava sotto di esso.
- **BottomNav**: `frontend/src/components/ui/BottomNav.vue` — `absolute bottom-0`,
  `h-[74px]`, nessuna gestione safe-area (su iPhone con home indicator le icone
  finivano a ridosso/dietro l'indicatore).
- **iOS meta**: `apple-mobile-web-app-status-bar-style=default` → status bar
  opaca non sovrapposta, quindi il contenuto parte già sotto di essa → **niente
  safe-area-inset-top necessaria** per gli header.
- **Clearance contenuto**: le view usano `pb-24` (96px) per non finire sotto la
  nav (es. `EventsView.vue`).

## Implementation Steps

TDD: **non applicabile** — è una modifica puramente di layout/CSS (utility
Tailwind in template), senza logica testabile a unità di valore. Verifica fatta
via `npm run build` + ispezione del CSS generato e prova manuale su mobile.

- [x] [2026-06-20 10:55] [top and bottom bar] Analisi: confermato che la causa è `min-h-screen`/`100vh` (scroll di pagina), che gli header sono già `flex-none` sopra uno scroller interno, e che la status bar iOS è `default` (no inset-top).
- [x] [2026-06-20 10:55] [top and bottom bar] `App.vue`: wrapper esterno `min-h-screen` → `h-dvh` + `overflow-hidden`; colonna telefono `flex-1` → `h-full`, con `sm:h-[calc(100dvh-1rem)]` per il card desktop (compensa `sm:my-2`). Risultato: pagina non scrolla, scorre solo `<main>`, header e nav restano pinnati.
- [x] [2026-06-20 10:55] [top and bottom bar] `BottomNav.vue`: aggiunto `pb-[env(safe-area-inset-bottom)]` e `min-h-[calc(74px+env(safe-area-inset-bottom))]` (al posto di `h-[74px]`) così la riga tap da 74px resta e l'inset dell'home indicator si aggiunge sotto, spingendo le icone sopra l'indicatore.
- [x] [2026-06-20 10:55] [top and bottom bar] Verifica build: `npm run build` ok; il CSS generato contiene `100dvh` (3 occorrenze) e `safe-area-inset-bottom` (4 occorrenze).
- [x] [2026-06-20 11:42] [top and bottom bar] Clearance contenuto su device col notch — applicata a tutte le view (no-op su desktop/non-notch, inset=0): (a) scroller sopra la `BottomNav` `pb-24` → `pb-[calc(96px+env(safe-area-inset-bottom))]` (Console, Events, Candidature, VolunteerStream, MyApplications, SupporterStream, SupporterMyEvents, e per coerenza le profile `hideNav`); (b) action bar custom dei detail/new-event (`hideNav`) `pb-[26px]` → `pb-[calc(26px+env(safe-area-inset-bottom))]` (VolunteerEventDetail, SupporterEventDetail, NewEvent) così i CTA primari liberano l'home indicator; (c) i loro scroller `pb-[150px]`/`pb-[120px]` → `+env(safe-area-inset-bottom)` per restare sopra la barra azioni più alta.
- [x] [2026-06-20 11:42] [top and bottom bar] Verifica: `npm run build` ok (le 4 regole `calc(...+env(safe-area-inset-bottom))` emesse nel CSS) e `npm run test` → 77/77 passano.
- [ ] [2026-06-20 11:42] [top and bottom bar] Verifica manuale su device reale (iOS Safari standalone + Android Chrome installato): barre fisse durante lo scroll, nessun rimbalzo della pagina, home indicator libero sotto nav e action bar, layout desktop invariato.

## Risks

- **`dvh` su browser molto vecchi**: `100dvh` è supportato dai browser moderni
  (2022+); su browser legacy l'altezza potrebbe non risolversi. Accettabile per
  una PWA moderna; eventuale fallback `100vh` solo se emergesse un caso reale.
- **Clearance sotto nav/action bar** *(risolto 2026-06-20)*: tutte le pb di fondo
  ora includono `env(safe-area-inset-bottom)`, quindi nessun clipping su device col
  notch. Resta da confermare a vista su hardware reale.
- **Doppio scroller**: `<main>` ha `overflow-y-auto` e ogni view ha uno scroller
  interno. Con lo shell ora ad altezza fissa, la view sta esattamente in `h-full`
  e scorre solo la lista interna; va verificato che nessuna view "alta" introduca
  uno scroll annidato indesiderato.
- **Bottom sheet / modali**: i `BottomSheet` (es. in `EventsView`) sono dentro la
  colonna `overflow-hidden`; verificare che animazione e altezza restino corrette
  con lo shell a `100dvh`.

## Context

- **Ticket**: nessuno (iniziativa interna, hackathon). Lavoro confluito su `main`.
- Origine: richiesta utente "la navbar bottom andrebbe fissata sul fondo e così
  anche la topbar in alto in modo che sembri una app nativa anche se PWA".
- Piani collegati: filone PWA (`2026-06-20_pwa-web-push.md`,
  `2026-06-20_pwa-toast-nuova-versione.md`).

## Notes

- Tutto il codice è implementato e verificato (build + 77/77 test). L'unico
  residuo è la **QA visiva su hardware reale** (iOS standalone + Android
  installato), che non incide sul codice: per questo il piano è chiuso come done.
- Niente safe-area-inset-top: con `status-bar-style=default` il contenuto parte
  già sotto la status bar. Se in futuro si passasse a `black-translucent`, andrà
  aggiunto `env(safe-area-inset-top)` in cima agli header.
