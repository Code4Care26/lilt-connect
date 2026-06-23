import { defineStore } from 'pinia'
import { api } from '../api'
import { setIdentity } from '../api/http'
import { usePushStore } from './push'

// Mock session for the prototype: no real login (Readme §10). The user types a
// name and the backend "authenticates" by deriving the role from it (magic-link
// simulation). The role therefore comes FROM the backend — never computed here.
// The chosen name is sent as X-Identity-Id on every request (via setIdentity).
//
// Default — before any login — is the anonymous guest: an unauthenticated
// supporter browsing the public stream.

const KEY = 'lilt-identity'
const DEFAULT_ROLE = 'supporter'

const ROLE_META = {
  supporter: { label: 'Simpatizzante', short: 'Simp.' },
  volunteer: { label: 'Volontario', short: 'Vol.' },
  staff: { label: 'Staff', short: 'Staff' },
}

// Avatar colour by role (presentation only).
const ROLE_COLOR = { supporter: '#0D9488', volunteer: '#0D9488', staff: '#4338CA' }
const GUEST_USER = { id: 'guest', name: 'Ospite', initials: '·', color: '#94A3B8' }

function loadPersisted() {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) {
      const v = JSON.parse(raw)
      if (v && v.name) return { name: v.name, role: v.role || DEFAULT_ROLE, initials: v.initials || '' }
    }
  } catch {
    /* ignore */
  }
  return { name: '', role: DEFAULT_ROLE, initials: '' }
}

export const useSessionStore = defineStore('session', {
  state: () => loadPersisted(),

  getters: {
    roleMeta: (state) => ROLE_META[state.role],
    roleLabel: (state) => ROLE_META[state.role].label,
    isSupporter: (state) => state.role === 'supporter',
    isVolunteer: (state) => state.role === 'volunteer',
    isStaff: (state) => state.role === 'staff',

    // A guest is anyone without a name: an unauthenticated supporter.
    isGuest: (state) => !state.name,
    authenticated: (state) => !!state.name,

    currentUser: (state) => {
      if (!state.name) return { ...GUEST_USER }
      return { id: state.name, name: state.name, initials: state.initials, color: ROLE_COLOR[state.role] }
    },
  },

  actions: {
    // Call once at startup so the persisted identity is sent on the first request.
    hydrate() {
      setIdentity(this.name)
    },

    persist() {
      try {
        if (this.name) localStorage.setItem(KEY, JSON.stringify({ name: this.name, role: this.role, initials: this.initials }))
        else localStorage.removeItem(KEY)
      } catch {
        /* ignore */
      }
    },

    // Magic-link login (immediate): the backend resolves name -> role.
    async login(rawName) {
      const name = (rawName || '').trim()
      if (!name) return
      const res = await api.session.create(name)
      this.name = res.name
      this.role = res.role
      this.initials = res.initials
      setIdentity(this.name)
      this.persist()
    },

    // Back to the anonymous guest. Drop the push subscription FIRST: the Rails
    // DELETE is scoped to the current identity, so it must run while the
    // X-Identity-Id header is still set. Best-effort — never blocks logout.
    async logout() {
      try {
        await usePushStore().disablePush()
      } catch {
        /* best-effort: a push cleanup failure must not prevent logout */
      }
      this.name = ''
      this.role = DEFAULT_ROLE
      this.initials = ''
      setIdentity('')
      this.persist()
    },
  },
})

export { ROLE_META }
