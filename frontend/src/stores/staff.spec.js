import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useStaffStore } from './staff'
import { useUiStore } from './ui'

// Backend-only app: stub the api module with an in-memory fake (see test/fakeApi).
vi.mock('../api', async () => {
  const { createFakeApi } = await import('../test/fakeApi')
  return { api: createFakeApi() }
})

// TDD anchor for the Staff console business logic (decision: spec-first).
// Exercises the store through its public actions/getters exactly as the views
// will. The store talks to the mock service layer; resetData() gives each test
// a clean, deterministic dataset (seed → localStorage → store).
describe('staff store', () => {
  let store

  beforeEach(async () => {
    setActivePinia(createPinia())
    store = useStaffStore()
    await store.resetData() // re-seeds the fake api, then reloads events
    await store.loadApplicants('e1') // open the managed event's applications
  })

  it('loads the events and the managed event applications', () => {
    expect(store.events).toHaveLength(5)
    expect(store.applicants).toHaveLength(9)
  })

  it('decorates events with lifecycle flags and a status banner', () => {
    const byId = Object.fromEntries(store.decoratedEvents.map((e) => [e.id, e]))
    expect(byId.e1.isPublished).toBe(true)
    expect(byId.e1.stat.text).toContain('candidature')
    expect(byId.e2.isDraft).toBe(true)
    expect(byId.e5.isCancelled).toBe(true)
    expect(byId.e5.stat.text).toContain('Adesioni insufficienti') // seeded reason
  })

  it('splits applicants into pending / approved / waitlist with correct counts', () => {
    expect(store.pendingCount).toBe(3)
    expect(store.approvedCount).toBe(4)
    expect(store.waitCount).toBe(2)
    expect(store.capacity).toBe(6)
    expect(store.fillPct).toBe(67) // round(4/6*100)
  })

  it('publishes a draft event', async () => {
    await store.publish('e2')
    expect(store.eventById('e2').isPublished).toBe(true)
    expect(useUiStore().toast.tone).toBe('publish')
  })

  it('cancels an event with a chosen reason via the sheet flow', async () => {
    store.openCancel('e1')
    expect(store.cancelOpen).toBe(true)
    expect(store.cancelTitle).toBe('Tour della Prevenzione')
    store.setCancelChoice('Maltempo')
    await store.confirmCancel()

    const e1 = store.eventById('e1')
    expect(e1.isCancelled).toBe(true)
    expect(e1.stat.text).toContain('Maltempo')
    expect(store.cancelOpen).toBe(false)
    expect(useUiStore().toast.tone).toBe('danger')
  })

  it('approves a pending applicant (pending -1, approved +1)', async () => {
    await store.approve('p1', 'Marco Conti')
    expect(store.pendingCount).toBe(2)
    expect(store.approvedCount).toBe(5)
    expect(store.applicants.find((a) => a.id === 'p1').status).toBe('approved')
  })

  it('moves an applicant to the waitlist', async () => {
    await store.moveToWaitlist('p2', 'Sara De Pieri')
    expect(store.waitCount).toBe(3)
    expect(store.pendingCount).toBe(2)
  })

  it('rejects an applicant by removing them entirely', async () => {
    await store.reject('p3', 'Luca Rossi')
    expect(store.applicants).toHaveLength(8)
    expect(store.pendingCount).toBe(2)
  })

  it('creates a new draft event at the top of the list', async () => {
    await store.createEvent({ title: 'Open day prevenzione', place: 'Piazza Garibaldi', dateLabel: '12 lug' }, { publish: false })
    expect(store.events).toHaveLength(6)
    expect(store.decoratedEvents[0].title).toBe('Open day prevenzione')
    expect(store.decoratedEvents[0].isDraft).toBe(true)
  })

  it('creates a published event when publish=true', async () => {
    await store.createEvent({ title: 'Screening estivo', place: 'Parco Iris', dateLabel: '20 lug' }, { publish: true })
    expect(store.decoratedEvents[0].isPublished).toBe(true)
  })

  it('updates an event in place without changing its status', async () => {
    await store.updateEvent('e1', { title: 'Tour della Prevenzione 2026', place: 'Prato della Valle' })
    const e1 = store.eventById('e1')
    expect(e1.title).toBe('Tour della Prevenzione 2026')
    expect(e1.place).toBe('Prato della Valle')
    expect(e1.isPublished).toBe(true) // lifecycle untouched
    expect(store.events).toHaveLength(5) // edited in place, not appended
    expect(useUiStore().toast.tone).toBe('ok')
  })

  it('resync() drops drifted in-memory state and re-pulls from the API (no backend reset)', async () => {
    // Simulate client drift: a stale/garbled in-memory state.
    store.events = [{ id: 'ghost', title: 'stale' }]
    store.managedEventId = 'e1'
    store.applicants = []

    await store.resync()

    expect(store.events).toHaveLength(5) // re-fetched from the API
    expect(store.managedEventId).toBe(null) // in-memory state was reset
    expect(store.loaded).toBe(true)
    expect(useUiStore().toast.text).toBe('Stato risincronizzato')
  })
})
