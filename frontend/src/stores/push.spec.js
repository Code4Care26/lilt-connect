import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { usePushStore } from './push'
import { api } from '../api'

// The api module is mocked: the store must talk to Rails only through it.
vi.mock('../api', () => ({
  api: { push: { vapidKey: vi.fn(), subscribe: vi.fn(), unsubscribe: vi.fn() } },
}))

// A real-looking VAPID public key (base64url) so urlBase64ToUint8Array/atob work.
const VAPID_PUBLIC = 'BFgh8EyRZqjz_QCXoSpypZRiCjXVs3yZtQDxakDDLxgf7WzGvkryRmYSYsAuRZHq4EEtl_s_XyBCd2-YZFROaKk='

function fakeSubscription(endpoint = 'https://push.example.com/dev') {
  return {
    endpoint,
    unsubscribe: vi.fn(async () => true),
    toJSON: () => ({ endpoint, keys: { p256dh: 'p256', auth: 'auth' } }),
  }
}

// Install the browser push APIs the store probes. Call BEFORE usePushStore(),
// because `supported`/`permission` are read at store creation.
function installPushEnv({ permission = 'default', granted = 'granted', existing = null } = {}) {
  const subscribe = vi.fn(async () => fakeSubscription('https://push.example.com/new'))
  const getSubscription = vi.fn(async () => existing)
  const reg = { pushManager: { subscribe, getSubscription } }
  vi.stubGlobal('Notification', { permission, requestPermission: vi.fn(async () => granted) })
  vi.stubGlobal('PushManager', function PushManager() {})
  Object.defineProperty(navigator, 'serviceWorker', {
    value: { ready: Promise.resolve(reg) },
    configurable: true,
  })
  return { subscribe, getSubscription, reg }
}

describe('push store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    api.push.vapidKey.mockResolvedValue({ publicKey: VAPID_PUBLIC })
    api.push.subscribe.mockResolvedValue({ ok: true })
    api.push.unsubscribe.mockResolvedValue(true)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.clearAllMocks()
    if (Object.getOwnPropertyDescriptor(navigator, 'serviceWorker')) delete navigator.serviceWorker
  })

  it('reports unsupported when the Push APIs are absent', () => {
    const store = usePushStore()
    expect(store.supported).toBe(false)
    expect(store.canPrompt).toBe(false)
  })

  it('enablePush: requests permission, subscribes, and persists to Rails', async () => {
    const { subscribe } = installPushEnv({ permission: 'default', granted: 'granted', existing: null })
    const store = usePushStore()

    const ok = await store.enablePush()

    expect(ok).toBe(true)
    expect(Notification.requestPermission).toHaveBeenCalledOnce()
    expect(subscribe).toHaveBeenCalledWith(
      expect.objectContaining({ userVisibleOnly: true, applicationServerKey: expect.any(Uint8Array) }),
    )
    expect(api.push.subscribe).toHaveBeenCalledWith({
      endpoint: 'https://push.example.com/new',
      keys: { p256dh: 'p256', auth: 'auth' },
    })
    expect(store.subscribed).toBe(true)
  })

  it('enablePush: stops and does not subscribe when permission is denied', async () => {
    const { subscribe } = installPushEnv({ granted: 'denied' })
    const store = usePushStore()

    const ok = await store.enablePush()

    expect(ok).toBe(false)
    expect(subscribe).not.toHaveBeenCalled()
    expect(api.push.subscribe).not.toHaveBeenCalled()
    expect(store.denied).toBe(true)
    expect(store.subscribed).toBe(false)
  })

  it('enablePush: reuses an existing pushManager subscription instead of re-subscribing', async () => {
    const existing = fakeSubscription('https://push.example.com/existing')
    const { subscribe } = installPushEnv({ existing })
    const store = usePushStore()

    await store.enablePush()

    expect(subscribe).not.toHaveBeenCalled()
    expect(api.push.subscribe).toHaveBeenCalledWith({
      endpoint: 'https://push.example.com/existing',
      keys: { p256dh: 'p256', auth: 'auth' },
    })
  })

  it('disablePush: unsubscribes locally and drops the row on Rails', async () => {
    const existing = fakeSubscription('https://push.example.com/gone')
    installPushEnv({ existing })
    const store = usePushStore()

    await store.disablePush()

    expect(existing.unsubscribe).toHaveBeenCalledOnce()
    expect(api.push.unsubscribe).toHaveBeenCalledWith('https://push.example.com/gone')
    expect(store.subscribed).toBe(false)
  })

  it('disablePush: no-op (never throws) when unsupported', async () => {
    const store = usePushStore()
    await expect(store.disablePush()).resolves.toBeUndefined()
    expect(api.push.unsubscribe).not.toHaveBeenCalled()
  })

  it('refresh: reflects an already-registered subscription without prompting', async () => {
    installPushEnv({ permission: 'granted', existing: fakeSubscription() })
    const store = usePushStore()

    await store.refresh()

    expect(store.subscribed).toBe(true)
    expect(Notification.requestPermission).not.toHaveBeenCalled()
  })
})
