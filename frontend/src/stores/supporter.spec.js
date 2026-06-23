import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useSupporterStore } from './supporter'
import { useUiStore } from './ui'

// Backend-only app: stub the api module with an in-memory fake (see test/fakeApi).
vi.mock('../api', async () => {
  const { createFakeApi } = await import('../test/fakeApi')
  return { api: createFakeApi() }
})

// TDD anchor for the Supporter experience: a simple per-event participation
// toggle (availability sent to staff), no approval lifecycle.
describe('supporter store', () => {
  let store

  beforeEach(async () => {
    setActivePinia(createPinia())
    store = useSupporterStore()
    await store.resetData()
  })

  it('loads the public events and the seeded participations', () => {
    expect(store.stream).toHaveLength(5)
    expect(store.myEvents).toHaveLength(1) // seeded: e3 (Pigiama Run)
    expect(store.myEvents[0].id).toBe('e3')
  })

  it('decorates events with the joined flag', () => {
    const byId = Object.fromEntries(store.stream.map((e) => [e.id, e]))
    expect(byId.e3.isJoined).toBe(true)
    expect(byId.e1.isJoined).toBe(false)
    expect(byId.e1.notJoined).toBe(true)
  })

  it('keeps a cancelled event visible with its reason, regardless of participation', () => {
    const e5 = store.eventById('e5') // cancelled, not joined
    expect(e5.isCancelled).toBe(true)
    expect(e5.reason).toBe('Adesioni insufficienti')
    expect(e5.isJoined).toBe(false)
    expect(store.stream.some((e) => e.id === 'e5')).toBe(true)
  })

  it('joins an event (toggle on)', async () => {
    await store.toggle('e1')
    expect(store.eventById('e1').isJoined).toBe(true)
    expect(store.myEvents).toHaveLength(2)
    expect(useUiStore().toast.tone).toBe('ok')
  })

  it('leaves an event (toggle off)', async () => {
    await store.toggle('e3')
    expect(store.eventById('e3').isJoined).toBe(false)
    expect(store.myEvents).toHaveLength(0)
    expect(useUiStore().toast.tone).toBe('info')
  })

  it('join and leave are idempotent on the joined map', async () => {
    await store.join('e2')
    await store.join('e2')
    expect(store.myEvents.filter((e) => e.id === 'e2')).toHaveLength(1)
    await store.leave('e2')
    expect(store.eventById('e2').isJoined).toBe(false)
  })

  it('exposes events carrying the public badge from the seed', () => {
    expect(store.eventById('e1').badge).toBe('Aperto a tutti')
    expect(store.eventById('e3').badge).toBe('Posti limitati')
  })
})
