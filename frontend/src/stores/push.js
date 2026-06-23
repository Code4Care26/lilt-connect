import { defineStore } from 'pinia'
import { api } from '../api'

// Web Push subscription state. This is the BACKGROUND channel: it reaches the
// device even with the app closed, complementing the SSE/gosse foreground
// stream. The flow is: ask permission (only after a user gesture) → subscribe
// via the SW's pushManager using the VAPID public key → POST the subscription
// to Rails, which sends notifications on domain events (e.g. candidatura
// accepted). On logout we unsubscribe locally AND tell Rails to drop the row.
//
// iOS Safari only exposes the Push API when the PWA is installed (standalone),
// so on a plain iOS tab `supported` stays false and the UI degrades to SSE.

// VAPID keys travel as base64url; pushManager wants a Uint8Array for
// applicationServerKey. Standard conversion (pad, swap URL-safe chars, decode).
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(base64)
  const out = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i)
  return out
}

function pushSupported() {
  return (
    typeof navigator !== 'undefined' &&
    'serviceWorker' in navigator &&
    typeof window !== 'undefined' &&
    'PushManager' in window &&
    'Notification' in window
  )
}

export const usePushStore = defineStore('push', {
  state: () => ({
    supported: pushSupported(),
    permission: typeof Notification !== 'undefined' ? Notification.permission : 'default',
    subscribed: false,
    busy: false,
  }),

  getters: {
    // Permanently blocked: we must not re-prompt (browsers ignore it anyway).
    denied: (state) => state.permission === 'denied',
    // Whether to offer the "Avvisami" toggle at all.
    canPrompt: (state) => state.supported && state.permission !== 'denied',
  },

  actions: {
    // Reflect the current registration state at startup / when opening the UI,
    // without prompting. Safe to call when unsupported (no-op).
    async refresh() {
      if (!this.supported) return
      this.permission = Notification.permission
      try {
        const reg = await navigator.serviceWorker.ready
        const sub = await reg.pushManager.getSubscription()
        this.subscribed = !!sub
      } catch {
        this.subscribed = false
      }
    },

    // Request permission (MUST be triggered by a user gesture), then subscribe
    // and persist to Rails. Returns true on success. Idempotent-ish: a second
    // call reuses the existing pushManager subscription if present.
    async enablePush() {
      if (!this.supported || this.busy) return false
      this.busy = true
      try {
        this.permission = await Notification.requestPermission()
        if (this.permission !== 'granted') return false

        const reg = await navigator.serviceWorker.ready
        const existing = await reg.pushManager.getSubscription()
        const { publicKey } = await api.push.vapidKey()
        if (!publicKey) return false

        const sub =
          existing ||
          (await reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(publicKey),
          }))

        await api.push.subscribe(sub.toJSON())
        this.subscribed = true
        return true
      } catch {
        return false
      } finally {
        this.busy = false
      }
    },

    // Unsubscribe this device locally AND drop the row on Rails. Best-effort:
    // called from logout, so it must never throw. Order matters — the Rails
    // DELETE must run while the identity header is still set (see session.logout).
    async disablePush() {
      if (!this.supported) return
      try {
        const reg = await navigator.serviceWorker.ready
        const sub = await reg.pushManager.getSubscription()
        if (sub) {
          const { endpoint } = sub
          await sub.unsubscribe()
          await api.push.unsubscribe(endpoint)
        }
      } catch {
        /* best-effort */
      } finally {
        this.subscribed = false
      }
    },
  },
})
