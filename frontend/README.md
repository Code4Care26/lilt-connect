# LILT — Frontend (PWA)

Single PWA serving all three LILT roles (supporter / volunteer / staff). The
default role — even when not logged in — is **supporter**. Auth is mocked for the
hackathon; a dev-only role switcher (top of the screen) flips between roles.

**Implemented so far:** the **Staff console** (events publish/cancel, volunteer
applications approve/waitlist/reject, cancel-reason sheet, new-event form).
Supporter and volunteer apps land in future steps.

## Stack

- Vue 3 (`<script setup>`) + Vue Router + Pinia
- Vite 6 · Tailwind CSS v4 (`@tailwindcss/vite`, no config file)
- Lucide icons · PWA via `vite-plugin-pwa`
- Vitest + @vue/test-utils for the store specs

## Commands

```bash
npm install
npm run dev        # dev server at http://localhost:5173
npm run build      # production build → dist/
npm run preview    # preview the production build
npm test           # run unit tests once
npm run test:watch # watch mode
```

## Architecture

```
src/
  api/            Service layer. Stores call this; never the data directly.
    mockDb.js     In-memory mock DB, persisted to localStorage (decision G).
    http.js       Rails HTTP adapter, same shape as mockDb (talks to /api).
    index.js      Facade — picks mockDb or httpApi via VITE_API_MODE (decision A).
  data/seed.js    Seed dataset (from the design canvas).
  stores/         Pinia: staff (events/applicants), session (role).
  components/ui/  Shared, role-agnostic primitives (Avatar, Toast, BottomSheet…).
  components/     Higher-level pieces (EventCard, RoleSwitcher).
  views/          One view per design frame (Events, Candidature, NewEvent, Profile).
  router.js       Routes mirror the design's navigation.
  App.vue         AppShell — picks UI by role.
```

## Data source: mock vs Rails backend

The facade `src/api/index.js` picks the implementation from `VITE_API_MODE`:

- **default (mock)** — `npm run dev` uses `mockDb` (in-memory + localStorage).
  Works offline, no backend needed.
- **backend** — `VITE_API_MODE=http npm run dev` uses `http.js`, which calls the
  Rails API at `/api`. The Vite dev server proxies `/api` → `http://localhost:3000`
  (see `vite.config.js`), so app and API share one origin (no CORS) and the PWA
  is reachable over the LAN (e.g. from a phone at `http://<your-ip>:5173`).

```bash
# terminal 1 — backend
cd ../backend && bin/rails db:setup && bin/rails server   # :3000

# terminal 2 — frontend talking to the backend
VITE_API_MODE=http npm run dev
```

Stores and views are identical in both modes — only the facade changes.

## Conventions

- Code, comments, and endpoint/resource names are in **English**.
- User-facing copy (labels, toasts) stays in **Italian** — the product language.
- Mobile-first only for now; desktop layouts are out of scope.
