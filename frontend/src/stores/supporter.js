import { defineStore } from 'pinia'
import { api } from '../api'
import { useUiStore } from './ui'

// Supporter experience store. The supporter browses public events and toggles
// participation (availability sent to staff) — a simple per-event boolean, no
// approval lifecycle. Independent from the Staff/Volunteer mocks. Toasts go
// through the shared `ui` store.

export const useSupporterStore = defineStore('supporter', {
  state: () => ({
    events: [],
    joined: {}, // eventId -> true
    loaded: false,
  }),

  getters: {
    decorate() {
      return (event) => {
        const isJoined = !!(this.joined || {})[event.id]
        // A cancelled event stays visible to everyone with its reason and offers
        // no participation action. `status`/`reason` are carried by `...event`.
        return { ...event, isJoined, notJoined: !isJoined, isCancelled: event.status === 'cancelled' }
      }
    },

    stream(state) {
      return state.events.map((e) => this.decorate(e))
    },

    eventById() {
      return (id) => {
        const e = this.events.find((x) => x.id === id)
        return e ? this.decorate(e) : null
      }
    },

    myEvents(state) {
      return state.events.filter((e) => state.joined[e.id]).map((e) => this.decorate(e))
    },

    joinedCount() {
      return this.myEvents.length
    },
  },

  actions: {
    async load() {
      const [events, joined] = await Promise.all([api.events.list(), api.participations.mine()])
      this.events = events
      this.joined = joined || {}
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

    async join(id, { guest = false } = {}) {
      this.joined = await api.participations.setJoined(id, true)
      useUiStore().showToast(
        guest
          ? 'Disponibilità inviata come ospite. Accedi per seguirne gli aggiornamenti.'
          : 'Disponibilità inviata. Lo staff LILT è stato avvisato.',
        'ok',
      )
    },
    async leave(id) {
      this.joined = await api.participations.setJoined(id, false)
      useUiStore().showToast('Partecipazione annullata.', 'info')
    },
    async toggle(id) {
      if (this.joined[id]) await this.leave(id)
      else await this.join(id)
    },
  },
})
