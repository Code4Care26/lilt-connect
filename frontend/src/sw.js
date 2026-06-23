// Custom service worker (vite-plugin-pwa `injectManifest` strategy).
//
// Why hand-written: the default generated SW (autoUpdate) cannot host the Web
// Push handlers. With injectManifest we own the SW, Workbox injects the precache
// manifest at build time (self.__WB_MANIFEST), and we add `push` /
// `notificationclick` for the background notification channel.
//
// Update flow is `prompt` (vite.config.js registerType): a new build waits in
// the "installed" state instead of self-activating. The app shows an "Aggiorna"
// toast; tapping it calls updateServiceWorker(true) in the page, which posts the
// SKIP_WAITING message handled below — only then do we activate and reload.
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { clientsClaim } from 'workbox-core'

// Precache the app shell (injected by Workbox at build time) and drop old revisions.
precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()

// Skip waiting only on demand (user tapped "Aggiorna"). vite-plugin-pwa's
// useRegisterSW posts { type: 'SKIP_WAITING' } when updateServiceWorker(true)
// runs; that triggers activation + a controllerchange-driven reload in the page.
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting()
})

// Once active, take control of open clients so the reload lands on the new SW.
clientsClaim()

// --- Web Push -------------------------------------------------------------
// Payload is intentionally thin (title/body/url) — coherent with the SSE
// invalidation model: the notification routes the user in, and the app re-fetches
// fresh state over REST on open. Rails sends it (see PushNotifier).
self.addEventListener('push', (event) => {
  let data = {}
  try {
    data = event.data ? event.data.json() : {}
  } catch {
    data = { title: event.data && event.data.text ? event.data.text() : 'LILT' }
  }

  const title = data.title || 'LILT'
  const options = {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    // Carried through to notificationclick so the tap knows where to go.
    data: { url: data.url || '/' },
  }
  event.waitUntil(self.registration.showNotification(title, options))
})

// Tap: focus an existing app window (navigating it to the target route) or open
// a new one. includeUncontrolled so a tab not yet controlled by this SW counts.
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = (event.notification.data && event.notification.data.url) || '/'

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          if ('navigate' in client) client.navigate(url)
          return client.focus()
        }
      }
      return self.clients.openWindow(url)
    }),
  )
})
