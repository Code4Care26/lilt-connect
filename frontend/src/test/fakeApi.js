// In-memory test double for the `api` module (src/api/index.js). The app is
// backend-only now, so the store specs stub `../api` with this fake instead of
// hitting the network. It mirrors the httpApi surface and is seeded with a
// fixed fixture so getters/actions can be exercised deterministically.
//
// Usage in a spec:
//   vi.mock('../api', async () => {
//     const { createFakeApi } = await import('../test/fakeApi')
//     return { api: createFakeApi() }
//   })
// Each test calls store.resetData() (-> api.reset()) in beforeEach for a clean slate.

const clone = (v) => JSON.parse(JSON.stringify(v))
const resolve = (v) => Promise.resolve(clone(v))

// Fixture = the demo dataset the store specs assert against.
export const FIXTURE = {
  events: [
    { id: 'e1', title: 'Tour della Prevenzione', badge: 'Aperto a tutti', status: 'published', reason: null, applicationsCount: 9, waitlistCount: 3, minParticipants: 11, missingParticipants: 2, needsParticipants: true, roles: ['Accoglienza'], slots: { approved: 8, available: 3 } },
    { id: 'e2', title: 'Cena di beneficenza', badge: 'Aperto a tutti', status: 'draft', reason: null, applicationsCount: 0, waitlistCount: 0, minParticipants: 10, missingParticipants: 10, needsParticipants: false, roles: ['Servizio'], slots: { approved: 5, available: 5 } },
    { id: 'e3', title: 'Pigiama Run 2026', badge: 'Posti limitati', status: 'published', reason: null, applicationsCount: 24, waitlistCount: 5, minParticipants: 24, missingParticipants: 0, needsParticipants: false, roles: ['Percorso'], slots: { approved: 18, available: 6 } },
    { id: 'e4', title: 'Festa del volontariato', badge: 'Aperto a tutti', status: 'draft', reason: null, applicationsCount: 0, waitlistCount: 0, minParticipants: 10, missingParticipants: 10, needsParticipants: false, roles: ['Accoglienza'], slots: { approved: 4, available: 6 } },
    { id: 'e5', title: 'Point in piazza', badge: 'Posti limitati', status: 'cancelled', reason: 'Adesioni insufficienti', applicationsCount: 0, waitlistCount: 0, minParticipants: 4, missingParticipants: 4, needsParticipants: false, roles: ['Info'], slots: { approved: 2, available: 2 } },
  ],
  applicants: [
    { id: 'p1', name: 'Marco Conti', initials: 'MC', pref: 'Accoglienza pubblico', color: '#0D9488', status: 'pending', eventId: 'e1' },
    { id: 'p2', name: 'Sara De Pieri', initials: 'SD', pref: 'Distribuzione materiale', color: '#7C3AED', status: 'pending', eventId: 'e1' },
    { id: 'p3', name: 'Luca Rossi', initials: 'LR', pref: 'Allestimento stand', color: '#DB2777', status: 'pending', eventId: 'e1' },
    { id: 'p4', name: 'Giulia Marchetti', initials: 'GM', pref: 'Accoglienza pubblico', color: '#2563EB', status: 'approved', eventId: 'e1' },
    { id: 'p5', name: 'Anna Bianchi', initials: 'AB', pref: 'Distribuzione materiale', color: '#0891B2', status: 'approved', eventId: 'e1' },
    { id: 'p6', name: 'Paolo Ferraro', initials: 'PF', pref: 'Allestimento stand', color: '#CA8A04', status: 'approved', eventId: 'e1' },
    { id: 'p7', name: 'Elena Greco', initials: 'EG', pref: 'Accoglienza pubblico', color: '#059669', status: 'approved', eventId: 'e1' },
    { id: 'p8', name: 'Franca Volpi', initials: 'FV', pref: 'Distribuzione materiale', color: '#475569', status: 'waitlist', eventId: 'e1' },
    { id: 'p9', name: 'Marta Ricci', initials: 'MR', pref: 'Allestimento stand', color: '#9333EA', status: 'waitlist', eventId: 'e1' },
  ],
  volunteerApp: { e1: 'approved', e2: 'pending', e3: 'supporter', e5: 'waitlist' },
  supporterJoined: { e3: true },
}

export function createFakeApi() {
  let state = clone(FIXTURE)
  const slug = (title) =>
    `ev-${String(title || 'evento').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 24) || 'nuovo'}-${state.events.length + 1}`

  return {
    reset() {
      state = clone(FIXTURE)
      return resolve(true)
    },

    session: {
      create: (name) =>
        resolve({
          name,
          role: /staff$/i.test(name.trim()) ? 'staff' : /vol$/i.test(name.trim()) ? 'volunteer' : 'supporter',
          initials: name.trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase(),
        }),
    },

    events: {
      list: () => resolve(state.events),
      get: (id) => resolve(state.events.find((e) => e.id === id) || null),
      create: (data) => {
        const ev = {
          id: slug(data.title),
          applicationsCount: 0,
          waitlistCount: 0,
          reason: null,
          roles: [],
          slots: { approved: 0, available: 0 },
          ...data,
          status: data.status || 'draft',
        }
        state.events = [ev, ...state.events]
        return resolve(ev)
      },
      update: (id, patch) => {
        let updated = null
        state.events = state.events.map((e) => (e.id === id ? (updated = { ...e, ...patch }) : e))
        return resolve(updated)
      },
    },

    applicants: {
      listByEvent: (eventId) => resolve(state.applicants.filter((a) => a.eventId === eventId)),
      update: (id, patch) => {
        let updated = null
        state.applicants = state.applicants.map((a) => (a.id === id ? (updated = { ...a, ...patch }) : a))
        return resolve(updated)
      },
      remove: (id) => {
        state.applicants = state.applicants.filter((a) => a.id !== id)
        return resolve(true)
      },
    },

    applications: {
      mine: () => resolve(state.volunteerApp),
      setStatus: (eventId, status) => {
        if (status == null) delete state.volunteerApp[eventId]
        else state.volunteerApp[eventId] = status
        return resolve(state.volunteerApp)
      },
    },

    participations: {
      mine: () => resolve(state.supporterJoined),
      setJoined: (eventId, joined) => {
        if (joined) state.supporterJoined[eventId] = true
        else delete state.supporterJoined[eventId]
        return resolve(state.supporterJoined)
      },
    },
  }
}
