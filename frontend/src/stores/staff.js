import { defineStore } from 'pinia'
import { api } from '../api'
import { useUiStore } from './ui'
import { STATUS_META, REASONS, CAPACITY } from '../data/meta'

// Staff console store. Holds the events + applicants loaded from the service
// layer and exposes the derived view data (decorated events, applicant groups,
// counts) as getters and the staff actions (publish/cancel/approve/…) as
// async actions that go through `api`. Never imports the mock data directly —
// that's the service layer's job (decision A). Toasts go through the shared
// `ui` store.

export const useStaffStore = defineStore('staff', {
  state: () => ({
    events: [],
    applicants: [],
    managedEventId: null, // event whose applications are currently loaded
    capacity: CAPACITY,
    loaded: false,

    dashboard: null, // Console data (GET /api/staff/dashboard), lazy-loaded on the Console tab

    // Cancel-reason sheet (modal over the Eventi view).
    cancelId: null,
    cancelChoice: 'Maltempo',
  }),

  getters: {
    reasons: () => REASONS,

    // Events decorated with lifecycle flags + the secondary status banner,
    // matching decorateEvent() in the design canvas.
    decoratedEvents(state) {
      return state.events.map((e) => {
        const meta = STATUS_META[e.status]
        let stat
        if (e.status === 'draft') {
          stat = { text: 'Bozza · non ancora visibile ai volontari', bg: '#F8FAFC', fg: '#64748B', icon: 'PencilLine' }
        } else if (e.status === 'cancelled') {
          stat = { text: `Causa: ${e.reason || '—'}`, bg: '#FEF2F2', fg: '#B91C1C', icon: 'TriangleAlert' }
        } else {
          stat = { text: `${e.applicationsCount} candidature · ${e.waitlistCount} in attesa`, bg: '#F0FDFA', fg: '#0F766E', icon: 'Users' }
        }
        return {
          ...e,
          isDraft: e.status === 'draft',
          isPublished: e.status === 'published',
          isCancelled: e.status === 'cancelled',
          chip: { ...meta },
          stat,
        }
      })
    },

    eventById() {
      return (id) => this.decoratedEvents.find((e) => e.id === id) || null
    },

    pendingList: (state) => state.applicants.filter((a) => a.status === 'pending'),
    approvedList: (state) => state.applicants.filter((a) => a.status === 'approved'),
    waitList: (state) => state.applicants.filter((a) => a.status === 'waitlist'),
    // Volunteers who pulled out: shown for awareness, not counted, no actions.
    withdrawnList: (state) => state.applicants.filter((a) => a.status === 'withdrawn'),

    pendingCount() {
      return this.pendingList.length
    },
    approvedCount() {
      return this.approvedList.length
    },
    waitCount() {
      return this.waitList.length
    },
    fillPct() {
      return Math.min(100, Math.round((this.approvedCount / this.capacity) * 100))
    },

    cancelOpen: (state) => !!state.cancelId,
    cancelTitle(state) {
      const ev = state.events.find((e) => e.id === state.cancelId)
      return ev ? ev.title : ''
    },
  },

  actions: {
    // --- Data loading ---
    async load() {
      this.events = await api.events.list()
      this.loaded = true
    },
    // Console "triage + retention" data, fetched on demand (hybrid backend).
    async loadDashboard() {
      this.dashboard = await api.staff.dashboard()
    },
    // Load the volunteer applications for one event (the "manage applications"
    // screen) and refresh that event's live counts.
    async loadApplicants(eventId) {
      this.managedEventId = eventId
      const [applicants, event] = await Promise.all([api.applicants.listByEvent(eventId), api.events.get(eventId)])
      this.applicants = applicants
      this._replaceEvent(event)
    },
    async resetData() {
      await api.reset()
      await this.load()
      if (this.managedEventId) await this.loadApplicants(this.managedEventId)
    },
    // Client-side resync (demo aid): drop any drifted in-memory state and re-pull
    // from the API. Does NOT touch backend data (unlike resetData) — use it when
    // the UI gets out of sync (e.g. a missed SSE invalidation).
    async resync() {
      this.$reset()
      await this.load()
      useUiStore().showToast('Stato risincronizzato')
    },

    // Re-fetch the managed event so its applicationsCount/waitlistCount reflect
    // a just-made decision.
    async _refreshManagedEvent() {
      if (this.managedEventId) this._replaceEvent(await api.events.get(this.managedEventId))
    },

    _replaceEvent(ev) {
      if (!ev) return
      const i = this.events.findIndex((e) => e.id === ev.id)
      if (i >= 0) this.events[i] = ev
    },
    _replaceApplicant(a) {
      if (!a) return
      const i = this.applicants.findIndex((x) => x.id === a.id)
      if (i >= 0) this.applicants[i] = a
    },

    // --- Event lifecycle ---
    async publish(id) {
      this._replaceEvent(await api.events.update(id, { status: 'published' }))
      useUiStore().showToast('Evento pubblicato. Ora è visibile ai volontari.', 'publish')
    },

    openCancel(id) {
      this.cancelId = id
      this.cancelChoice = 'Maltempo'
    },
    closeCancel() {
      this.cancelId = null
    },
    setCancelChoice(reason) {
      this.cancelChoice = reason
    },
    async confirmCancel() {
      const id = this.cancelId
      const why = this.cancelChoice
      this._replaceEvent(await api.events.update(id, { status: 'cancelled', reason: why }))
      this.cancelId = null
      useUiStore().showToast(`Evento annullato (${why}). I volontari sono stati avvisati.`, 'danger')
    },

    async createEvent(data, { publish } = {}) {
      const ev = await api.events.create({ ...data, status: publish ? 'published' : 'draft' })
      this.events.unshift(ev)
      useUiStore().showToast(
        publish ? 'Evento pubblicato. Ora è visibile ai volontari.' : 'Bozza salvata.',
        publish ? 'publish' : 'ok',
      )
    },

    // Edit an existing event (the Modifica flow). Sends only the fields the form
    // owns; the event's status/lifecycle is left to publish/cancel. The PATCH
    // endpoint already exists (Event::WRITE_KEYS).
    async updateEvent(id, data) {
      this._replaceEvent(await api.events.update(id, data))
      useUiStore().showToast('Modifiche salvate.', 'ok')
    },

    // --- Applicant decisions ---
    async approve(id, name) {
      this._replaceApplicant(await api.applicants.update(id, { status: 'approved' }))
      await this._refreshManagedEvent()
      useUiStore().showToast(`${name} approvato come volontario.`, 'publish')
    },
    async moveToWaitlist(id, name) {
      this._replaceApplicant(await api.applicants.update(id, { status: 'waitlist' }))
      await this._refreshManagedEvent()
      useUiStore().showToast(`${name} spostato in lista di riserva.`, 'info')
    },
    async reject(id, name) {
      await api.applicants.remove(id)
      this.applicants = this.applicants.filter((a) => a.id !== id)
      await this._refreshManagedEvent()
      useUiStore().showToast(`Candidatura di ${name} rifiutata.`, 'danger')
    },
  },
})
