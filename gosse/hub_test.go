package main

import (
	"bytes"
	"testing"
)

func TestPublishReachesSubscriber(t *testing.T) {
	h := NewHub()
	ch := h.Subscribe()
	defer h.Unsubscribe(ch)

	h.Publish([]byte(`{"type":"events.changed","id":"e1"}`))

	select {
	case msg := <-ch:
		if !bytes.Equal(msg, []byte(`{"type":"events.changed","id":"e1"}`)) {
			t.Fatalf("unexpected payload: %s", msg)
		}
	default:
		t.Fatal("subscriber received nothing")
	}
}

func TestFanOutToEverySubscriber(t *testing.T) {
	h := NewHub()
	a := h.Subscribe()
	b := h.Subscribe()
	defer h.Unsubscribe(a)
	defer h.Unsubscribe(b)

	h.Publish([]byte(`{"type":"reset"}`))

	for _, ch := range []chan []byte{a, b} {
		select {
		case msg := <-ch:
			if string(msg) != `{"type":"reset"}` {
				t.Fatalf("unexpected payload: %s", msg)
			}
		default:
			t.Fatal("a subscriber missed the fan-out")
		}
	}
}

func TestUnsubscribeStopsDelivery(t *testing.T) {
	h := NewHub()
	ch := h.Subscribe()
	if got := h.Count(); got != 1 {
		t.Fatalf("Count = %d, want 1", got)
	}
	h.Unsubscribe(ch)
	if got := h.Count(); got != 0 {
		t.Fatalf("Count after unsubscribe = %d, want 0", got)
	}
	// Publishing must not panic with no subscribers and must not deliver.
	h.Publish([]byte(`{"type":"events.changed","id":"e2"}`))
}

func TestPublishNonBlockingOnFullSubscriber(t *testing.T) {
	h := NewHub()
	ch := h.Subscribe()
	defer h.Unsubscribe(ch)

	// Overfill: more publishes than the buffer holds. Publish must never block;
	// the excess is dropped.
	for i := 0; i < subBuffer+10; i++ {
		h.Publish([]byte(`{"type":"spam"}`))
	}
	if len(ch) > subBuffer {
		t.Fatalf("channel length %d exceeds buffer %d", len(ch), subBuffer)
	}
}
