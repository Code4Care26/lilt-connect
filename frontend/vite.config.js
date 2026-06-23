import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

// LILT Staff console — Vue 3 + Tailwind v4 + PWA.
// Auth is mocked for the hackathon (no real login), so the PWA is a pure
// client-side shell talking to a future Rails API.
// The `test` block is consumed by Vitest (jsdom gives us localStorage for the
// mock DB specs); Vite itself ignores it.
export default defineConfig({
  // Dev server: expose on the LAN (host:true) so the PWA is reachable from a
  // phone, and proxy '/api' to the Rails backend. Relative URLs in http.js mean
  // the same origin serves app + API in dev — no CORS needed.
  server: {
    host: true,
    proxy: {
      // REST API -> Rails
      '/api': 'http://localhost:3000',
      // Realtime SSE stream -> gosse (Go service). Vite streams SSE through
      // without buffering, so the plain string form is enough.
      '/sse': 'http://localhost:3002',
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
  },
  plugins: [
    vue(),
    tailwindcss(),
    VitePWA({
      // Custom SW (src/sw.js) so we can handle Web Push `push`/`notificationclick`.
      // Workbox injects the precache manifest into it at build time.
      // `prompt` (not autoUpdate): a new build does NOT self-activate. The app
      // surfaces an "Aggiorna" toast (useRegisterSW.needRefresh) and only on tap
      // calls updateServiceWorker(true), which messages the waiting SW to
      // skipWaiting and then reloads. See 2026-06-20_pwa-toast-nuova-versione.md.
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.js',
      registerType: 'prompt',
      includeAssets: ['favicon.svg'],
      manifest: {
        name: 'LILT · Console Staff',
        short_name: 'LILT Staff',
        description: 'Gestione eventi e candidature volontari LILT',
        lang: 'it',
        // Stable identity for the installed app, decoupled from start_url so a
        // future change to start_url won't be treated as a different app.
        id: '/',
        categories: ['productivity', 'health', 'lifestyle'],
        theme_color: '#0D9488',
        background_color: '#E7E5DF',
        display: 'standalone',
        start_url: '/',
        // `any` icons are used as-is; the `maskable` one is full-bleed teal with
        // the shield inside the 80% safe zone, so launchers can crop it to any
        // shape (circle/squircle) without clipping the logo or showing a square.
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
        // Drives Chrome's richer install dialog. `sizes` MUST match the real
        // pixels or Chrome drops the screenshot. NOTE: these are branded
        // placeholders — replace with real captures before public launch.
        screenshots: [
          { src: 'screenshot-1.png', sizes: '1080x1920', type: 'image/png', form_factor: 'narrow', label: 'Stream eventi LILT' },
          { src: 'screenshot-2.png', sizes: '1080x1920', type: 'image/png', form_factor: 'narrow', label: 'Dettaglio evento e candidatura' },
        ],
        // Long-press shortcuts. Global (not per-role): each target route already
        // self-protects via its `meta.role` guard in App.vue, so a wrong-role tap
        // bounces to that role's home.
        shortcuts: [
          { name: 'Eventi', short_name: 'Eventi', url: '/events', description: 'Vai allo stream eventi' },
          { name: 'Nuovo evento', short_name: 'Nuovo', url: '/events/new', description: 'Crea un nuovo evento' },
          { name: 'Le mie candidature', short_name: 'Candidature', url: '/volunteer/applications', description: 'Le tue candidature da volontario' },
        ],
      },
    }),
  ],
})
