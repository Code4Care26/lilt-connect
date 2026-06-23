package main

import (
	"context"
	"log"
	"os"

	"github.com/redis/go-redis/v9"
)

// broadcaster decides where a /publish payload goes before it reaches the local
// SSE clients. Two implementations:
//
//   - localBroadcaster: single process. Hand the message straight to the hub.
//   - redisBroadcaster: many processes. PUBLISH to a Redis channel; every gosse
//     instance (including this one) gets it back through its SUBSCRIBE loop and
//     fans it out to *its own* clients. This is what makes gosse horizontally
//     scalable — see kapsule/README.md §3.2 (opzione A).
//
// Note the asymmetry of the Redis path: handlePublish does NOT touch the hub
// directly. Delivery to local clients happens only via the subscription, so the
// instance that received the POST delivers exactly once, like every other
// instance — no double frame.
type broadcaster interface {
	// Broadcast hands one invalidation message to all clients across all
	// instances. Fire-and-forget: a delivery failure is logged, never returned,
	// because invalidations are ephemeral (a client re-syncs on the next message
	// or on reconnect).
	Broadcast(msg []byte)
}

// localBroadcaster is the single-instance path: no shared bus, deliver in-process.
type localBroadcaster struct{ hub *Hub }

func (b localBroadcaster) Broadcast(msg []byte) { b.hub.Publish(msg) }

// redisBroadcaster fans messages out across every gosse instance through a Redis
// pub/sub channel. The local hub is still used, but only as the per-instance
// fan-out reached from the subscription loop (see subscribe).
type redisBroadcaster struct {
	client  *redis.Client
	channel string
}

// newRedisBroadcaster parses a redis:// or rediss:// (TLS) URL and pings the
// server so a misconfiguration fails loudly at boot rather than silently
// swallowing every future publish.
func newRedisBroadcaster(redisURL, channel string) (*redisBroadcaster, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, err
	}
	// Il Redis gestito Scaleway presenta un certificato TLS firmato da una CA
	// privata, non nel bundle pubblico (immagine distroless). Sul Private Network
	// il traffico è già isolato: REDIS_TLS_INSECURE salta la verifica del
	// certificato mantenendo la connessione cifrata. Vedi kapsule/README.md §3.2.
	if opts.TLSConfig != nil && os.Getenv("REDIS_TLS_INSECURE") != "" {
		opts.TLSConfig.InsecureSkipVerify = true
	}
	client := redis.NewClient(opts)
	if err := client.Ping(context.Background()).Err(); err != nil {
		return nil, err
	}
	return &redisBroadcaster{client: client, channel: channel}, nil
}

// Broadcast publishes the message to the shared channel. It does NOT deliver to
// the local hub — that happens when the message comes back via subscribe, so
// every instance (this one included) delivers through the same path.
func (b *redisBroadcaster) Broadcast(msg []byte) {
	if err := b.client.Publish(context.Background(), b.channel, msg).Err(); err != nil {
		log.Printf("redis publish: %v", err)
	}
}

// subscribe runs for the life of the process: it relays every message on the
// channel — whoever published it — to this instance's local SSE clients. Blocks,
// so run it in its own goroutine.
func (b *redisBroadcaster) subscribe(ctx context.Context, hub *Hub) {
	sub := b.client.Subscribe(ctx, b.channel)
	defer sub.Close()
	for msg := range sub.Channel() {
		hub.Publish([]byte(msg.Payload))
	}
}
