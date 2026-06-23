package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// spyBroadcaster records every Broadcast call so tests can assert what
// handlePublish forwarded (and what it didn't).
type spyBroadcaster struct {
	mu   sync.Mutex
	msgs [][]byte
}

func (s *spyBroadcaster) Broadcast(msg []byte) {
	s.mu.Lock()
	s.msgs = append(s.msgs, append([]byte(nil), msg...))
	s.mu.Unlock()
}

func (s *spyBroadcaster) calls() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.msgs)
}

// TestLocalBroadcasterDeliversToHub proves the single-instance path: a message
// handed to localBroadcaster reaches a hub subscriber.
func TestLocalBroadcasterDeliversToHub(t *testing.T) {
	h := NewHub()
	ch := h.Subscribe()
	defer h.Unsubscribe(ch)

	localBroadcaster{h}.Broadcast([]byte(`{"type":"reset"}`))

	select {
	case msg := <-ch:
		if string(msg) != `{"type":"reset"}` {
			t.Fatalf("unexpected payload: %s", msg)
		}
	default:
		t.Fatal("subscriber received nothing")
	}
}

// TestPublishRoutesThroughBroadcaster proves handlePublish forwards the body to
// the broadcaster — and only after the auth and JSON-validity gates pass.
func TestPublishRoutesThroughBroadcaster(t *testing.T) {
	spy := &spyBroadcaster{}
	srv := &server{hub: NewHub(), broadcaster: spy, secret: "s3cret"}
	ts := httptest.NewServer(srv.routes())
	defer ts.Close()

	post := func(secret, body string) int {
		req, _ := http.NewRequest(http.MethodPost, ts.URL+"/publish", strings.NewReader(body))
		if secret != "" {
			req.Header.Set("X-Sse-Secret", secret)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		return res.StatusCode
	}

	// Wrong secret: rejected, broadcaster untouched.
	if got := post("", `{"type":"reset"}`); got != http.StatusUnauthorized {
		t.Fatalf("no secret: status = %d, want 401", got)
	}
	// Invalid JSON: rejected, broadcaster untouched.
	if got := post("s3cret", "not json{"); got != http.StatusBadRequest {
		t.Fatalf("bad json: status = %d, want 400", got)
	}
	if spy.calls() != 0 {
		t.Fatalf("broadcaster called %d times before a valid request", spy.calls())
	}

	// Valid request: forwarded verbatim.
	if got := post("s3cret", `{"type":"events.changed","id":"e1"}`); got != http.StatusNoContent {
		t.Fatalf("valid: status = %d, want 204", got)
	}
	if spy.calls() != 1 {
		t.Fatalf("broadcaster calls = %d, want 1", spy.calls())
	}
	if got := string(spy.msgs[0]); got != `{"type":"events.changed","id":"e1"}` {
		t.Fatalf("forwarded body = %q", got)
	}
}
