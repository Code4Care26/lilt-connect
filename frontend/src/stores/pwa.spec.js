import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { usePwaStore } from './pwa'

// A fake BeforeInstallPromptEvent: only the bits our store touches.
// `userChoice` is a promise resolving to { outcome } like the real API.
function fakePrompt(outcome = 'accepted') {
  return {
    preventDefault: vi.fn(),
    prompt: vi.fn(),
    userChoice: Promise.resolve({ outcome }),
  }
}

// TDD anchor for the custom install flow. The store is the only testable piece
// of the PWA-installability work (manifest/meta/assets are static config). It
// models the Chromium `beforeinstallprompt` lifecycle: capture → arm (after a
// key action) → prompt → installed, plus the "already installed / iOS / no
// event" cases where the custom button must stay hidden.
describe('pwa install store', () => {
  let store

  beforeEach(() => {
    setActivePinia(createPinia())
    store = usePwaStore()
  })

  it('starts with no install affordance', () => {
    expect(store.canInstall).toBe(false)
    expect(store.showInstallButton).toBe(false)
  })

  it('captures beforeinstallprompt and suppresses the browser mini-infobar', () => {
    const evt = fakePrompt()
    store.capturePrompt(evt)
    expect(evt.preventDefault).toHaveBeenCalledOnce()
    expect(store.canInstall).toBe(true)
  })

  it('keeps the custom button hidden until armed by a key action', () => {
    store.capturePrompt(fakePrompt())
    expect(store.showInstallButton).toBe(false) // captured but not armed yet
    store.arm()
    expect(store.showInstallButton).toBe(true)
  })

  it('does not show the button when armed but no prompt was captured (e.g. iOS)', () => {
    store.arm()
    expect(store.canInstall).toBe(false)
    expect(store.showInstallButton).toBe(false)
  })

  it('hides the button when already running standalone', () => {
    store.capturePrompt(fakePrompt())
    store.arm()
    store.standalone = true
    expect(store.canInstall).toBe(false)
    expect(store.showInstallButton).toBe(false)
  })

  it('prompts, awaits the choice, and marks installed on accept', async () => {
    const evt = fakePrompt('accepted')
    store.capturePrompt(evt)
    store.arm()
    const outcome = await store.promptInstall()
    expect(evt.prompt).toHaveBeenCalledOnce()
    expect(outcome).toBe('accepted')
    expect(store.installed).toBe(true)
    expect(store.deferredPrompt).toBe(null) // single-use, dropped after firing
    expect(store.showInstallButton).toBe(false)
  })

  it('drops the event on dismiss but does not mark installed', async () => {
    const evt = fakePrompt('dismissed')
    store.capturePrompt(evt)
    store.arm()
    const outcome = await store.promptInstall()
    expect(outcome).toBe('dismissed')
    expect(store.installed).toBe(false)
    expect(store.deferredPrompt).toBe(null)
  })

  it('promptInstall is a no-op when there is no captured event', async () => {
    const outcome = await store.promptInstall()
    expect(outcome).toBe(null)
  })

  it('appinstalled marks installed and clears the affordance', () => {
    store.capturePrompt(fakePrompt())
    store.arm()
    store.onInstalled()
    expect(store.installed).toBe(true)
    expect(store.showInstallButton).toBe(false)
  })

  it('can be dismissed by the user without installing', () => {
    store.capturePrompt(fakePrompt())
    store.arm()
    expect(store.showInstallButton).toBe(true)
    store.dismiss()
    expect(store.showInstallButton).toBe(false)
    expect(store.canInstall).toBe(true) // still installable, just not nagging
  })
})
