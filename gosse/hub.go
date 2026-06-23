package main

import "sync"

// subBuffer is the per-subscriber channel capacity. A client slower than the
// publishers fills this and then has messages dropped (see Publish) rather than
// stalling everyone. Invalidation semantics make a drop harmless: the client
// re-syncs via REST on the next message or on reconnect.
const subBuffer = 64

// Hub is an in-memory fan-out registry of SSE subscribers. No persistence: a
// published message reaches whoever is connected at that instant and is then
// forgotten. The hub is per-instance — it only knows the clients connected to
// *this* process. Across multiple gosse instances the shared bus lives one
// layer up, in redisBroadcaster (see broadcast.go): every instance subscribes
// to the same Redis channel and calls this hub to fan out to its own clients.
type Hub struct {
	mu   sync.RWMutex
	subs map[chan []byte]struct{}
}

func NewHub() *Hub {
	return &Hub{subs: make(map[chan []byte]struct{})}
}

// Subscribe registers a new subscriber and returns its (buffered) channel.
func (h *Hub) Subscribe() chan []byte {
	ch := make(chan []byte, subBuffer)
	h.mu.Lock()
	h.subs[ch] = struct{}{}
	h.mu.Unlock()
	return ch
}

// Unsubscribe removes a subscriber and closes its channel. Idempotent. Holding
// the write lock guarantees no Publish is mid-send on this channel when we close
// it (Publish takes the read lock — the two are mutually exclusive).
func (h *Hub) Unsubscribe(ch chan []byte) {
	h.mu.Lock()
	if _, ok := h.subs[ch]; ok {
		delete(h.subs, ch)
		close(ch)
	}
	h.mu.Unlock()
}

// Publish fans msg out to every subscriber, non-blocking: a full channel (slow
// client) drops the message instead of stalling the publisher.
func (h *Hub) Publish(msg []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for ch := range h.subs {
		select {
		case ch <- msg:
		default: // subscriber buffer full — drop (see subBuffer)
		}
	}
}

// Count returns the number of live subscribers (used by tests and /healthz).
func (h *Hub) Count() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.subs)
}
