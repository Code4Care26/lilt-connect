// HTTP adapter for the Rails backend — the single source of truth (see ./index.js).
//
// URLs are relative ('/api/...'): in dev the Vite proxy forwards them to the
// Rails server (vite.config.js), which also makes the PWA reachable over the LAN
// (e.g. from a phone) without any CORS setup.
//
// Mock auth (Readme §10): identity is a free-form name. `setIdentity(name)` is
// called by the session store on login/logout/init; every request then carries
// it as `X-Identity-Id`. The backend derives the role from the name — the
// frontend never sends or computes the role.

const BASE = '/api'

// Current identity (the user's name), or '' for the anonymous guest.
let currentIdentity = ''
export function setIdentity(name) {
  currentIdentity = (name || '').trim()
}

async function send(method, path, { body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(currentIdentity ? { 'X-Identity-Id': currentIdentity } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  // 204 has no body; everything else returns JSON (objects, arrays, true, null).
  return res.status === 204 ? null : res.json()
}

export const httpApi = {
  reset: () => send('POST', '/reset'),

  // Magic-link login simulation: resolve a name to { name, role, initials }.
  session: {
    create: (name) => send('POST', '/session', { body: { name } }),
  },

  events: {
    list: () => send('GET', '/events'),
    get: (id) => send('GET', `/events/${id}`),
    create: (data) => send('POST', '/events', { body: data }),
    update: (id, patch) => send('PATCH', `/events/${id}`, { body: patch }),
  },

  applicants: {
    listByEvent: (eventId) => send('GET', `/events/${eventId}/applicants`),
    update: (id, patch) => send('PATCH', `/applicants/${id}`, { body: patch }),
    remove: (id) => send('DELETE', `/applicants/${id}`),
  },

  // "mine" endpoints act on the current identity (X-Identity-Id header).
  applications: {
    mine: () => send('GET', '/applications/mine'),
    setStatus: (eventId, status) => send('PUT', `/applications/mine/${eventId}`, { body: { status } }),
  },

  participations: {
    mine: () => send('GET', '/participations/mine'),
    setJoined: (eventId, joined) => send('PUT', `/participations/mine/${eventId}`, { body: { joined } }),
  },

  // "Il tuo impatto": motivational stats for the current volunteer's profile.
  volunteer: {
    stats: () => send('GET', '/volunteer/stats'),
  },

  // Console staff: triage + retention data (hybrid backend — see StaffDashboardController).
  staff: {
    dashboard: () => send('GET', '/staff/dashboard'),
  },

  // Web Push: the VAPID public key (to build applicationServerKey), plus
  // subscribe/unsubscribe of the current device. The subscription is bound to
  // the current identity (X-Identity-Id) server-side — see PushSubscriptionsController.
  push: {
    vapidKey: () => send('GET', '/push/vapid_public_key'),
    subscribe: (subscription) => send('POST', '/push/subscriptions', { body: { subscription } }),
    unsubscribe: (endpoint) => send('DELETE', '/push/subscriptions', { body: { endpoint } }),
  },
}
