require "net/http"
require "uri"

# Realtime forwards invalidation messages to the gosse SSE service over HTTP.
# Rails no longer streams SSE itself (that moved to the gosse/ Go service): the
# models' after_commit hooks call Realtime.publish, and here we POST the small
# invalidation JSON ({ type, id/eventId }) to gosse /publish. gosse fans it out
# to the connected browsers, which re-sync via the normal REST API — so we send
# no domain state and persist nothing.
#
# Best-effort by design: the POST runs in a detached thread with short timeouts
# and rescues everything, so a slow or unreachable gosse NEVER delays or fails a
# mutation. A lost invalidation is harmless — the client re-syncs on its next
# message or on reconnect.
#
# No-op when SSE_PUBLISH_URL is unset, so Rails (and the test suite) run fine
# without gosse.
module Realtime
  OPEN_TIMEOUT = 0.5
  READ_TIMEOUT = 0.5

  class << self
    # Pluggable delivery: a callable (url, body, headers). Defaults to a real
    # HTTP POST; tests swap it for a recording double.
    attr_writer :transport

    def transport
      @transport ||= method(:http_post)
    end

    # Forward an invalidation hash to gosse. Returns the JSON body that was
    # dispatched, or nil when disabled (no endpoint configured).
    def publish(payload)
      url = endpoint
      return nil if url.empty?

      body = payload.to_json
      hdrs = headers
      # Fire-and-forget: never block the request thread on gosse.
      Thread.new { deliver(url, body, hdrs) }
      body
    end

    private

    def endpoint
      ENV["SSE_PUBLISH_URL"].to_s
    end

    def headers
      h = { "Content-Type" => "application/json" }
      secret = ENV["SSE_PUBLISH_SECRET"].to_s
      h["X-Sse-Secret"] = secret unless secret.empty?
      h
    end

    # Best-effort delivery: any error (gosse down, timeout, DNS, …) is logged and
    # swallowed so it can never bubble into the mutation that triggered it.
    def deliver(url, body, hdrs)
      transport.call(url, body, hdrs)
    rescue StandardError => e
      Rails.logger.warn("[Realtime] publish to gosse failed: #{e.class}: #{e.message}") if defined?(Rails)
    end

    def http_post(url, body, hdrs)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      request = Net::HTTP::Post.new(uri.request_uri)
      hdrs.each { |k, v| request[k] = v }
      request.body = body
      http.request(request)
    end
  end
end
