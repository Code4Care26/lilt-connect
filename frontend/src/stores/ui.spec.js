import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useUiStore } from './ui'

// TDD anchor for the "actionable, persistent" toast variant added for the PWA
// update flow. The plain `showToast` auto-dismisses at 3s; the update toast must
// stay until the user acts (or it's explicitly cleared), and must carry an
// action ({ label, run }) the <Toast> renders as a button.
describe('ui store', () => {
  let store

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useUiStore()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('starts with no toast', () => {
    expect(store.toast).toBe(null)
  })

  it('showToast auto-dismisses after 3s', () => {
    store.showToast('Salvato', 'ok')
    expect(store.toast).toEqual({ text: 'Salvato', tone: 'ok' })
    vi.advanceTimersByTime(3000)
    expect(store.toast).toBe(null)
  })

  it('showActionToast keeps an action and does NOT auto-dismiss', () => {
    const run = vi.fn()
    store.showActionToast('Nuova versione', 'info', { label: 'Aggiorna', run })
    expect(store.toast).toEqual({
      text: 'Nuova versione',
      tone: 'info',
      action: { label: 'Aggiorna', run },
    })
    // Well past the normal auto-dismiss window: still there.
    vi.advanceTimersByTime(10000)
    expect(store.toast).not.toBe(null)
    expect(store.toast.action.run).toBe(run)
  })

  it('showActionToast cancels a pending auto-dismiss from a previous showToast', () => {
    store.showToast('Salvato', 'ok')
    // Before the 3s timer fires, replace it with a persistent action toast.
    vi.advanceTimersByTime(1500)
    store.showActionToast('Nuova versione', 'info', { label: 'Aggiorna', run: vi.fn() })
    // The leftover 3s timer must NOT clear the persistent toast.
    vi.advanceTimersByTime(5000)
    expect(store.toast?.text).toBe('Nuova versione')
  })

  it('clearToast removes a persistent action toast', () => {
    store.showActionToast('Nuova versione', 'info', { label: 'Aggiorna', run: vi.fn() })
    store.clearToast()
    expect(store.toast).toBe(null)
  })
})
