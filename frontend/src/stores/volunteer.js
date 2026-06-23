import { defineStore } from 'pinia'
import { api } from '../api'
import { useUiStore } from './ui'
import { usePwaStore } from './pwa'
import { VOLUNTEER_APP_META, VOLUNTEER_STATUS_ORDER, VOLUNTEER_ENGAGEMENT_META } from '../data/meta'

// Volunteer experience store. Holds the public events catalogue and the current
// volunteer's per-event application status, and exposes the stream + "my
// applications" as getters and the lifecycle actions (apply / participate /
// withdraw / drop out) as async actions through the service layer.
// Toasts go through the shared `ui` store. Independent from the Staff mock.

export const useVolunteerStore = defineStore('volunteer', {
  state: () => ({
    events: [],
    app: {}, // eventId -> 'supporter' | 'pending' | 'approved' | 'waitlist'
    loaded: false,
    confirmId: null, // event pending a drop-out confirmation
    stats: null, // "Il tuo impatto" profile stats (lazy-loaded on the profile)
  }),

  getters: {
    // One decorated event: merges the volunteer's application status + flags.
    decorate() {
      return (event) => {
        const status = (this.app || {})[event.id] || null
        const meta = status ? VOLUNTEER_APP_META[status] : null
        // "Ingaggio" badge: the backend decides (needsParticipants) whether the
        // event still needs volunteers and how many are missing — we only build
        // the presentational badge. Null when not needed (no badge rendered).
        const engagement = event.needsParticipants
          ? { ...VOLUNTEER_ENGAGEMENT_META, label: VOLUNTEER_ENGAGEMENT_META.label(event.missingParticipants) }
          : null
        return {
          ...event,
          // Defaults so events missing the volunteer detail fields (e.g. ones
          // created Staff-side, or legacy persisted blobs) never crash a view.
          roles: event.roles || [],
          slots: event.slots || { approved: 0, available: 0 },
          // Event lifecycle (NOT the application status, which `status` below
          // shadows): a cancelled event stays visible to everyone with its
          // reason and offers no actions. `reason` is carried by `...event`.
          isCancelled: event.status === 'cancelled',
          status,
          engagement,
          stNone: !status,
          stSupporter: status === 'supporter',
          stPending: status === 'pending',
          stApproved: status === 'approved',
          stWaitlist: status === 'waitlist',
          stWithdrawn: status === 'withdrawn',
          canWithdraw: status === 'pending' || status === 'waitlist',
          chip: meta ? { ...meta } : null,
        }
      }
    },

    // Full public catalogue (decision J: the volunteer's own public events).
    stream(state) {
      return state.events.map((e) => this.decorate(e))
    },

    eventById() {
      return (id) => {
        const e = this.events.find((x) => x.id === id)
        return e ? this.decorate(e) : null
      }
    },

    // Events the volunteer is engaged with, ordered approved → pending →
    // waitlist → supporter.
    myApplications(state) {
      return state.events
        .filter((e) => state.app[e.id])
        .sort((a, b) => VOLUNTEER_STATUS_ORDER[state.app[a.id]] - VOLUNTEER_STATUS_ORDER[state.app[b.id]])
        .map((e) => this.decorate(e))
    },

    confirmOpen: (state) => !!state.confirmId,
    confirmTitle(state) {
      const e = state.events.find((x) => x.id === state.confirmId)
      return e ? e.title : ''
    },
  },

  actions: {
    async load() {
      const [events, app] = await Promise.all([api.events.list(), api.applications.mine()])
      this.events = events
      this.app = app || {}
      this.loaded = true
    },
    async resetData() {
      await api.reset()
      await this.load()
    },
    // Client-side resync (demo aid): drop any drifted in-memory state and re-pull
    // from the API. Does NOT touch backend data (unlike resetData) — use it when
    // the UI gets out of sync (e.g. a missed SSE invalidation).
    async resync() {
      this.$reset()
      await this.load()
      useUiStore().showToast('Stato risincronizzato')
    },

    // Profile "Il tuo impatto": fetched on demand (placeholder random data
    // backend-side for now).
    async loadStats() {
      this.stats = await api.volunteer.stats()
    },

    async _setStatus(eventId, status) {
      this.app = await api.applications.setStatus(eventId, status)
    },

    async applyAsVolunteer(id) {
      await this._setStatus(id, 'pending')
      useUiStore().showToast('Adesione inviata. In attesa di approvazione dallo staff.', 'info')
      // Key action reached: arm the custom install offer (no-op on iOS / when
      // already installed — the pwa store decides whether the button shows).
      usePwaStore().arm()
    },
    async participateAsSupporter(id) {
      await this._setStatus(id, 'supporter')
      useUiStore().showToast('Partecipi come sostenitore. Lo staff è stato avvisato.', 'ok')
    },
    // Rinuncia: the application is kept as `withdrawn` (not deleted), so it
    // stays visible to both the volunteer and the staff.
    async withdraw(id) {
      await this._setStatus(id, 'withdrawn')
      useUiStore().showToast('Adesione ritirata.', 'info')
    },
    // Cancelling a supporter participation is not a candidatura withdrawal: it
    // just removes the supporter record.
    async cancelSupporter(id) {
      await this._setStatus(id, null)
      useUiStore().showToast('Partecipazione annullata.', 'info')
    },

    // Drop-out ("tira pacco") requires confirmation: you held a confirmed spot.
    askDropOut(id) {
      this.confirmId = id
    },
    cancelDropOut() {
      this.confirmId = null
    },
    async confirmDropOut() {
      const id = this.confirmId
      this.confirmId = null
      await this._setStatus(id, 'withdrawn')
      useUiStore().showToast('Hai rinunciato. Lo staff e la lista di riserva sono stati avvisati.', 'danger')
    },
  },
})
