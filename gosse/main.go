// Command gosse is a tiny Server-Sent Events fan-out service.
//
// It owns the realtime layer that used to live inside Rails (ActionController::
// Live). Rails no longer streams: after every mutation it POSTs a small
// *invalidation* message ({type, id/eventId}) to gosse /publish, and gosse fans
// it out to the connected browsers on /sse/stream. The browser reacts by
// re-fetching through the normal REST API, so gosse carries no domain state and
// persists nothing.
//
// Why Go: every SSE connection is a goroutine (cheap), not an OS/Puma thread,
// and a client disconnect cancels the request Context immediately — so a dead
// connection frees its goroutine at once, with no heartbeat-based detection.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// heartbeatInterval keeps the connection alive through idle-timeout proxies.
// Unlike the Rails version it is NOT how we detect disconnects (the request
// Context does that instantly) — only a keep-alive.
const heartbeatInterval = 15 * time.Second

// maxPublishBody caps the /publish payload (invalidations are tiny).
const maxPublishBody = 64 << 10 // 64 KiB

type server struct {
	hub         *Hub
	broadcaster broadcaster // where /publish payloads go (local hub or Redis fan-out)
	secret      string      // shared secret required on /publish (empty = no check)
	origin      string      // Access-Control-Allow-Origin for /sse/stream (empty = none)
}

// defaultRedisChannel is the pub/sub channel every gosse instance publishes to
// and subscribes from. Override with REDIS_CHANNEL if a Redis is shared.
const defaultRedisChannel = "gosse.invalidations"

func main() {
	host := getenv("HOST", "127.0.0.1") // localhost by default: /publish must not be world-reachable
	port := getenv("PORT", "3002")
	hub := NewHub()
	s := &server{
		hub:    hub,
		secret: os.Getenv("SSE_PUBLISH_SECRET"),
		origin: os.Getenv("ALLOWED_ORIGIN"),
	}
	if s.secret == "" {
		log.Print("warning: SSE_PUBLISH_SECRET not set — /publish is unauthenticated")
	}

	// REDIS_URL switches gosse from single-instance (in-memory only) to a
	// horizontally scalable fan-out: /publish PUBLISHes to a shared channel and a
	// background SUBSCRIBE loop delivers to this instance's clients. See
	// kapsule/README.md §3.2.
	if redisURL := os.Getenv("REDIS_URL"); redisURL != "" {
		rb, err := newRedisBroadcaster(redisURL, getenv("REDIS_CHANNEL", defaultRedisChannel))
		if err != nil {
			log.Fatalf("redis: %v", err)
		}
		go rb.subscribe(context.Background(), hub)
		s.broadcaster = rb
		log.Printf("gosse: redis fan-out enabled (channel %q)", rb.channel)
	} else {
		s.broadcaster = localBroadcaster{hub}
		log.Print("gosse: single-instance mode — REDIS_URL not set, in-memory fan-out only")
	}

	addr := host + ":" + port
	log.Printf("gosse listening on %s", addr)
	if err := http.ListenAndServe(addr, s.routes()); err != nil {
		log.Fatal(err)
	}
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("GET /sse/stream", s.handleStream)
	mux.HandleFunc("POST /publish", s.handlePublish)
	return mux
}

func (s *server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	fmt.Fprintf(w, "ok %d\n", s.hub.Count())
}

// handleStream is the long-lived SSE connection for a browser client.
func (s *server) handleStream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "text/event-stream")
	h.Set("Cache-Control", "no-cache")
	h.Set("Connection", "keep-alive")
	h.Set("X-Accel-Buffering", "no") // defeat proxy buffering (nginx/Thruster/Vite)
	if s.origin != "" {
		h.Set("Access-Control-Allow-Origin", s.origin)
	}

	ch := s.hub.Subscribe()
	defer s.hub.Unsubscribe(ch)

	// Greeting: flushes headers through any proxy and signals the stream is live.
	fmt.Fprint(w, ": connected\n\n")
	flusher.Flush()

	ticker := time.NewTicker(heartbeatInterval)
	defer ticker.Stop()

	ctx := r.Context()
	for {
		select {
		case <-ctx.Done():
			return // client disconnected — the goroutine returns immediately
		case msg := <-ch:
			// msg is the raw invalidation JSON relayed verbatim (single line).
			fmt.Fprintf(w, "data: %s\n\n", msg)
			flusher.Flush()
		case <-ticker.C:
			fmt.Fprint(w, ": ping\n\n")
			flusher.Flush()
		}
	}
}

// handlePublish is the internal endpoint Rails calls after a mutation. It
// authenticates with a shared secret, then relays the JSON body to all clients.
func (s *server) handlePublish(w http.ResponseWriter, r *http.Request) {
	if s.secret != "" && r.Header.Get("X-Sse-Secret") != s.secret {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxPublishBody))
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if !json.Valid(body) {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	s.broadcaster.Broadcast(body)
	w.WriteHeader(http.StatusNoContent)
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
