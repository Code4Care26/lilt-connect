import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { connectStream, disconnectStream } from './stream'

// Verify the SSE client: it opens an EventSource at /sse/stream (carrying the
// identity in the query string), forwards parsed message payloads to the
// handler, ignores malformed frames, and closes the previous connection on
// reconnect/disconnect. jsdom has no EventSource, so we stub it.

let instances

class MockEventSource {
  constructor(url) {
    this.url = url
    this.onmessage = null
    this.closed = false
    instances.push(this)
  }
  close() {
    this.closed = true
  }
  // Test helper: simulate a server-sent data frame.
  emit(data) {
    this.onmessage?.({ data })
  }
}

beforeEach(() => {
  instances = []
  vi.stubGlobal('EventSource', MockEventSource)
})
afterEach(() => {
  disconnectStream()
  vi.unstubAllGlobals()
})

describe('connectStream', () => {
  it('opens /sse/stream with the identity in the query string', () => {
    connectStream('Anna Staff', () => {})
    expect(instances).toHaveLength(1)
    expect(instances[0].url).toBe('/sse/stream?identity=Anna%20Staff')
  })

  it('omits the identity for an anonymous guest', () => {
    connectStream('', () => {})
    expect(instances[0].url).toBe('/sse/stream')
  })

  it('forwards parsed message payloads to the handler', () => {
    const seen = []
    connectStream('x', (msg) => seen.push(msg))
    instances[0].emit(JSON.stringify({ type: 'events.changed', id: 'e2' }))
    instances[0].emit(JSON.stringify({ type: 'reset' }))
    expect(seen).toEqual([{ type: 'events.changed', id: 'e2' }, { type: 'reset' }])
  })

  it('ignores a malformed frame without throwing', () => {
    const seen = []
    connectStream('x', (msg) => seen.push(msg))
    expect(() => instances[0].emit('not json{')).not.toThrow()
    expect(seen).toEqual([])
  })

  it('closes the previous connection when reconnecting', () => {
    connectStream('a', () => {})
    const first = instances[0]
    connectStream('b', () => {})
    expect(first.closed).toBe(true)
    expect(instances).toHaveLength(2)
  })
})

describe('disconnectStream', () => {
  it('closes the live connection', () => {
    connectStream('a', () => {})
    disconnectStream()
    expect(instances[0].closed).toBe(true)
  })

  it('is a no-op when nothing is connected', () => {
    expect(() => disconnectStream()).not.toThrow()
  })
})
