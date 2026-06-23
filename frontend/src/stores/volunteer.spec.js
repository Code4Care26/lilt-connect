import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useVolunteerStore } from './volunteer'
import { useUiStore } from './ui'

// Backend-only app: stub the api module with an in-memory fake (see test/fakeApi).
vi.mock('../api', async () => {
  const { createFakeApi } = await import('../test/fakeApi')
  return { api: createFakeApi() }
})

// TDD anchor for the Volunteer experience. Exercises the store as the views
// will: a per-event application status for the current volunteer, with the
// lifecycle none → supporter | pending, pending/waitlist → none (withdraw),
// approved → none (drop out, confirmed).
describe('volunteer store', () => {
  let store

  beforeEach(async () => {
    setActivePinia(createPinia())
    store = useVolunteerStore()
    await store.resetData()
  })

  it('loads the shared events and the seeded application state', () => {
    expect(store.stream).toHaveLength(5)
    // Seeded: e1 approved, e2 pending, e3 supporter, e5 waitlist (e4 none)
    expect(store.myApplications).toHaveLength(4)
  })

  it('decorates events with the application status', () => {
    const byId = Object.fromEntries(store.stream.map((e) => [e.id, e]))
    expect(byId.e1.status).toBe('approved')
    expect(byId.e1.stApproved).toBe(true)
    expect(byId.e1.chip.label).toBe('Volontario approvato')
    expect(byId.e4.stNone).toBe(true)
    expect(byId.e4.chip).toBe(null)
  })

  it('flags a cancelled event with its reason, even when the volunteer applied to it', () => {
    const e5 = store.eventById('e5') // cancelled AND seeded as the volunteer's waitlist
    expect(e5.isCancelled).toBe(true)
    expect(e5.reason).toBe('Adesioni insufficienti')
    // The application status is still there underneath, but the views key off
    // isCancelled to show the cancelled banner instead of any action.
    expect(e5.status).toBe('waitlist')
  })

  it('sorts "my applications" approved → pending → waitlist → supporter', () => {
    expect(store.myApplications.map((e) => e.id)).toEqual(['e1', 'e2', 'e5', 'e3'])
  })

  it('exposes canWithdraw only for pending and waitlist', () => {
    const byId = Object.fromEntries(store.stream.map((e) => [e.id, e]))
    expect(byId.e2.canWithdraw).toBe(true) // pending
    expect(byId.e5.canWithdraw).toBe(true) // waitlist
    expect(byId.e1.canWithdraw).toBe(false) // approved
    expect(byId.e3.canWithdraw).toBe(false) // supporter
    expect(byId.e4.canWithdraw).toBe(false) // none
  })

  it('applies as volunteer (none → pending)', async () => {
    await store.applyAsVolunteer('e4')
    expect(store.eventById('e4').status).toBe('pending')
    expect(store.myApplications).toHaveLength(5)
    expect(useUiStore().toast.tone).toBe('info')
  })

  it('participates as supporter (none → supporter)', async () => {
    await store.participateAsSupporter('e4')
    expect(store.eventById('e4').stSupporter).toBe(true)
    expect(useUiStore().toast.tone).toBe('ok')
  })

  it('withdraws a pending application -> withdrawn, kept in the list', async () => {
    await store.withdraw('e2')
    expect(store.eventById('e2').status).toBe('withdrawn')
    expect(store.eventById('e2').stWithdrawn).toBe(true)
    expect(store.myApplications).toHaveLength(4) // stays: ritirato non sparisce
  })

  it('a withdrawn volunteer can re-apply (withdrawn → pending)', async () => {
    await store.withdraw('e2')
    await store.applyAsVolunteer('e2')
    expect(store.eventById('e2').status).toBe('pending')
  })

  it('cancels a supporter participation (supporter → none, removed)', async () => {
    await store.cancelSupporter('e3')
    expect(store.eventById('e3').status).toBe(null)
  })

  it('drops out of an approved event only after confirmation -> withdrawn', async () => {
    store.askDropOut('e1')
    expect(store.confirmOpen).toBe(true)
    expect(store.confirmTitle).toBe('Tour della Prevenzione')

    await store.confirmDropOut()
    expect(store.eventById('e1').status).toBe('withdrawn')
    expect(store.confirmOpen).toBe(false)
    expect(useUiStore().toast.tone).toBe('danger')
  })

  it('can cancel the drop-out confirmation without changing status', () => {
    store.askDropOut('e1')
    store.cancelDropOut()
    expect(store.confirmOpen).toBe(false)
    expect(store.eventById('e1').status).toBe('approved')
  })

  it('decorate supplies safe defaults for events missing detail fields', () => {
    // e.g. a Staff-created or legacy event without roles/slots — must not crash.
    const decorated = store.decorate({ id: 'x', title: 'Bare event' })
    expect(decorated.roles).toEqual([])
    expect(decorated.slots).toEqual({ approved: 0, available: 0 })
    expect(decorated.stNone).toBe(true)
    expect(decorated.engagement).toBe(null) // no needsParticipants flag -> no badge
  })

  it('decorates an "ingaggio" badge when the event still needs participants', () => {
    // e1 (published): backend reports needsParticipants with 2 missing.
    const byId = Object.fromEntries(store.stream.map((e) => [e.id, e]))
    expect(byId.e1.engagement).not.toBe(null)
    expect(byId.e1.engagement.label).toContain('2')
    // e3 (published, minimum reached) and e5 (cancelled, below min) get no badge.
    expect(byId.e3.engagement).toBe(null)
    expect(byId.e5.engagement).toBe(null)
  })
})
