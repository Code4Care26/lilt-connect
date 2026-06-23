import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { httpApi, setIdentity } from './http'

// Verify the http adapter: each method hits the right verb + path under /api,
// propagates the parsed JSON body, and carries the current identity as
// X-Identity-Id on every request (set via setIdentity). The backend derives the
// role from the name, so there is no X-Role. fetch is stubbed (no server).

let calls

function mockFetch(body, { status = 200 } = {}) {
  return vi.fn((url, opts = {}) => {
    calls.push({ url, method: opts.method || 'GET', body: opts.body ? JSON.parse(opts.body) : undefined, headers: opts.headers })
    return Promise.resolve({ status, json: () => Promise.resolve(body) })
  })
}

beforeEach(() => {
  calls = []
  setIdentity('') // anonymous by default
})
afterEach(() => {
  vi.unstubAllGlobals()
  setIdentity('')
})

describe('identity header', () => {
  it('omits X-Identity-Id when anonymous (guest)', async () => {
    vi.stubGlobal('fetch', mockFetch([]))
    await httpApi.events.list()
    expect(calls[0].headers['X-Identity-Id']).toBeUndefined()
  })

  it('sends X-Identity-Id on every request once an identity is set, and never X-Role', async () => {
    vi.stubGlobal('fetch', mockFetch([]))
    setIdentity('giulia vol')
    await httpApi.events.list()
    await httpApi.applications.mine()
    expect(calls[0].headers['X-Identity-Id']).toBe('giulia vol')
    expect(calls[1].headers['X-Identity-Id']).toBe('giulia vol')
    expect(calls[0].headers['X-Role']).toBeUndefined()
  })
})

describe('httpApi.session', () => {
  it('create -> POST /api/session with {name}', async () => {
    vi.stubGlobal('fetch', mockFetch({ name: 'Anna Staff', role: 'staff', initials: 'AS' }))
    const res = await httpApi.session.create('Anna Staff')
    expect(calls[0]).toMatchObject({ url: '/api/session', method: 'POST', body: { name: 'Anna Staff' } })
    expect(res).toEqual({ name: 'Anna Staff', role: 'staff', initials: 'AS' })
  })
})

describe('httpApi.events', () => {
  it('list -> GET /api/events', async () => {
    vi.stubGlobal('fetch', mockFetch([{ id: 'e1' }]))
    const res = await httpApi.events.list()
    expect(calls[0]).toMatchObject({ url: '/api/events', method: 'GET' })
    expect(res).toEqual([{ id: 'e1' }])
  })

  it('get -> GET /api/events/:id, propagates null', async () => {
    vi.stubGlobal('fetch', mockFetch(null))
    const res = await httpApi.events.get('nope')
    expect(calls[0]).toMatchObject({ url: '/api/events/nope', method: 'GET' })
    expect(res).toBeNull()
  })

  it('create -> POST /api/events with JSON body', async () => {
    vi.stubGlobal('fetch', mockFetch({ id: 'ev-x-6' }))
    await httpApi.events.create({ title: 'X', status: 'draft' })
    expect(calls[0]).toMatchObject({ url: '/api/events', method: 'POST', body: { title: 'X', status: 'draft' } })
  })

  it('update -> PATCH /api/events/:id with patch body', async () => {
    vi.stubGlobal('fetch', mockFetch({ id: 'e2', status: 'published' }))
    await httpApi.events.update('e2', { status: 'published' })
    expect(calls[0]).toMatchObject({ url: '/api/events/e2', method: 'PATCH', body: { status: 'published' } })
  })
})

describe('httpApi.applicants', () => {
  it('listByEvent -> GET /api/events/:id/applicants', async () => {
    vi.stubGlobal('fetch', mockFetch([]))
    await httpApi.applicants.listByEvent('e1')
    expect(calls[0]).toMatchObject({ url: '/api/events/e1/applicants', method: 'GET' })
  })

  it('update -> PATCH /api/applicants/:id', async () => {
    vi.stubGlobal('fetch', mockFetch({ id: 'p1', status: 'approved' }))
    await httpApi.applicants.update('p1', { status: 'approved' })
    expect(calls[0]).toMatchObject({ url: '/api/applicants/p1', method: 'PATCH', body: { status: 'approved' } })
  })

  it('remove -> DELETE /api/applicants/:id, propagates true', async () => {
    vi.stubGlobal('fetch', mockFetch(true))
    const res = await httpApi.applicants.remove('p1')
    expect(calls[0]).toMatchObject({ url: '/api/applicants/p1', method: 'DELETE' })
    expect(res).toBe(true)
  })
})

describe('httpApi.applications', () => {
  it('mine -> GET /api/applications/mine', async () => {
    vi.stubGlobal('fetch', mockFetch({ e1: 'approved' }))
    const res = await httpApi.applications.mine()
    expect(calls[0]).toMatchObject({ url: '/api/applications/mine', method: 'GET' })
    expect(res).toEqual({ e1: 'approved' })
  })

  it('setStatus -> PUT /api/applications/mine/:eventId with {status}', async () => {
    vi.stubGlobal('fetch', mockFetch({ e4: 'pending' }))
    await httpApi.applications.setStatus('e4', 'pending')
    expect(calls[0]).toMatchObject({ url: '/api/applications/mine/e4', method: 'PUT', body: { status: 'pending' } })
  })

  it('setStatus with null status sends {status:null} (delete)', async () => {
    vi.stubGlobal('fetch', mockFetch({}))
    await httpApi.applications.setStatus('e1', null)
    expect(calls[0].body).toEqual({ status: null })
  })
})

describe('httpApi.participations', () => {
  it('mine -> GET /api/participations/mine', async () => {
    vi.stubGlobal('fetch', mockFetch({ e3: true }))
    await httpApi.participations.mine()
    expect(calls[0]).toMatchObject({ url: '/api/participations/mine', method: 'GET' })
  })

  it('setJoined -> PUT /api/participations/mine/:eventId with {joined}', async () => {
    vi.stubGlobal('fetch', mockFetch({ e1: true }))
    await httpApi.participations.setJoined('e1', true)
    expect(calls[0]).toMatchObject({ url: '/api/participations/mine/e1', method: 'PUT', body: { joined: true } })
  })
})

describe('httpApi.reset', () => {
  it('reset -> POST /api/reset, propagates true', async () => {
    vi.stubGlobal('fetch', mockFetch(true))
    const res = await httpApi.reset()
    expect(calls[0]).toMatchObject({ url: '/api/reset', method: 'POST' })
    expect(res).toBe(true)
  })
})
