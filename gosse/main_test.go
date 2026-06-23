package main

import (
	"bufio"
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newTestServer(secret string) *server {
	h := NewHub()
	return &server{hub: h, broadcaster: localBroadcaster{h}, secret: secret}
}

func TestHealthz(t *testing.T) {
	ts := httptest.NewServer(newTestServer("").routes())
	defer ts.Close()

	res, err := http.Get(ts.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.StatusCode)
	}
}

func TestPublishRequiresSecret(t *testing.T) {
	ts := httptest.NewServer(newTestServer("s3cret").routes())
	defer ts.Close()

	body := strings.NewReader(`{"type":"reset"}`)

	// No secret → 401.
	res, err := http.Post(ts.URL+"/publish", "application/json", body)
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusUnauthorized {
		t.Fatalf("without secret: status = %d, want 401", res.StatusCode)
	}

	// Correct secret → 204.
	req, _ := http.NewRequest(http.MethodPost, ts.URL+"/publish", strings.NewReader(`{"type":"reset"}`))
	req.Header.Set("X-Sse-Secret", "s3cret")
	res, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNoContent {
		t.Fatalf("with secret: status = %d, want 204", res.StatusCode)
	}
}

func TestPublishRejectsInvalidJSON(t *testing.T) {
	ts := httptest.NewServer(newTestServer("").routes())
	defer ts.Close()

	res, err := http.Post(ts.URL+"/publish", "application/json", strings.NewReader("not json{"))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", res.StatusCode)
	}
}

// TestStreamGreetingAndMessage proves the full path: a client connects, gets the
// greeting, then a published message is delivered as an SSE data frame. The
// request Context is cancelled to end the stream — demonstrating the clean,
// immediate disconnect that makes this testable (unlike a Rails Live action).
func TestStreamGreetingAndMessage(t *testing.T) {
	srv := newTestServer("")
	ts := httptest.NewServer(srv.routes())
	defer ts.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, ts.URL+"/sse/stream", nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()

	if ct := res.Header.Get("Content-Type"); ct != "text/event-stream" {
		t.Fatalf("Content-Type = %q, want text/event-stream", ct)
	}

	reader := bufio.NewReader(res.Body)

	// 1) Greeting comment.
	line := readLine(t, reader)
	if line != ": connected" {
		t.Fatalf("first line = %q, want %q", line, ": connected")
	}
	readLine(t, reader) // blank line terminating the greeting

	// 2) Wait for the subscriber to be registered, then publish.
	waitFor(t, func() bool { return srv.hub.Count() == 1 })
	srv.hub.Publish([]byte(`{"type":"events.changed","id":"e9"}`))

	// 3) The data frame arrives.
	data := readLine(t, reader)
	if data != `data: {"type":"events.changed","id":"e9"}` {
		t.Fatalf("data line = %q", data)
	}

	// 4) Cancelling the context ends the stream and frees the goroutine.
	cancel()
	waitFor(t, func() bool { return srv.hub.Count() == 0 })
}

// readLine reads one line with a timeout so a stalled stream fails fast instead
// of hanging the test.
func readLine(t *testing.T, r *bufio.Reader) string {
	t.Helper()
	type result struct {
		s   string
		err error
	}
	out := make(chan result, 1)
	go func() {
		line, err := r.ReadString('\n')
		out <- result{line, err}
	}()
	select {
	case v := <-out:
		if v.err != nil {
			t.Fatalf("read: %v", v.err)
		}
		return strings.TrimRight(v.s, "\n")
	case <-time.After(2 * time.Second):
		t.Fatal("read timed out")
		return ""
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("condition not met within 2s")
}
