// Realtime SSE client. Opens an EventSource to the gosse service at /sse/stream
// (proxied to the Go service by Vite in dev) and hands each *invalidation*
// message ({ type, ... }) to a callback. The app reacts by re-fetching through
// the normal REST endpoints (see the stores' load()), so the stream never
// carries domain state — only "something changed".
//
// Identity travels in the query string because EventSource cannot send custom
// headers (the REST API uses the X-Identity-Id header, set in http.js).
//
// Reconnection is handled by the browser: EventSource retries automatically
// after a drop, and because nothing is persisted server-side the caller simply
// re-syncs via REST on the next message. We keep a single live connection.

const BASE = '/sse'

let source = null

// Open (or re-open) the stream for `identity`, routing every message to
// `onMessage`. Closes any previous connection first so we never leak sockets
// or run two streams at once.
export function connectStream(identity, onMessage) {
  disconnectStream()
  const qs = identity ? `?identity=${encodeURIComponent(identity)}` : ''
  source = new EventSource(`${BASE}/stream${qs}`)
  source.onmessage = (event) => {
    let payload
    try {
      payload = JSON.parse(event.data)
    } catch {
      return // ignore a malformed frame
    }
    onMessage(payload)
  }
  // No onerror handler: EventSource reconnects on its own. A handler that
  // called source.close() here would defeat that auto-recovery.
  return source
}

export function disconnectStream() {
  if (source) {
    source.close()
    source = null
  }
}
