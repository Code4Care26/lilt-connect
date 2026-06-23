require "web-push"

# PushNotifier sends Web Push (VAPID) notifications to all of an identity's
# registered browsers. It is the background complement to Realtime/gosse SSE:
# SSE only reaches open tabs, push reaches a closed app.
#
# Mirrors Realtime's design on purpose:
#   * pluggable `transport` (tests swap in a recording/raising double);
#   * no-op when not configured (VAPID keys unset) — the suite and a keyless
#     dev box run fine without delivering anything;
#   * best-effort — a flaky push service never bubbles into the mutation that
#     triggered the notification.
#
# Unlike Realtime it owns a tiny bit of state: when the push service reports a
# subscription as gone (404/410) we prune that row, so dead devices don't
# accumulate. Transient errors (timeouts, 5xx) are swallowed WITHOUT pruning.
module PushNotifier
  class << self
    # Pluggable delivery: a callable (subscription, payload_json, vapid_hash).
    attr_writer :transport

    def transport
      @transport ||= method(:web_push_send)
    end

    # Notify every subscription of `identity_id` with a thin payload (the SW
    # shows title/body and routes to `url`; the app re-fetches over REST on tap,
    # staying consistent with the SSE invalidation model). Returns the number of
    # subscriptions delivered to, or nil when disabled.
    def notify(identity_id, title:, body: nil, url: "/")
      return nil unless configured?

      payload = { title: title, body: body, url: url }.compact.to_json
      delivered = 0
      PushSubscription.for_identity(identity_id).find_each do |subscription|
        delivered += 1 if deliver(subscription, payload)
      end
      delivered
    end

    private

    def configured?
      !ENV["VAPID_PUBLIC_KEY"].to_s.empty? && !ENV["VAPID_PRIVATE_KEY"].to_s.empty?
    end

    # Returns true on (apparent) success, false when the subscription was pruned
    # or a transient error was swallowed.
    def deliver(subscription, payload)
      transport.call(subscription, payload, vapid)
      true
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      # 410 Gone / 404 Not Found: the browser unsubscribed or the endpoint died.
      subscription.destroy
      false
    rescue StandardError => e
      Rails.logger.warn("[PushNotifier] delivery failed: #{e.class}: #{e.message}") if defined?(Rails)
      false
    end

    def web_push_send(subscription, payload, vapid)
      WebPush.payload_send(
        message: payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: vapid
      )
    end

    def vapid
      {
        subject: ENV["VAPID_SUBJECT"].to_s.empty? ? "mailto:noreply@lilt-connect.local" : ENV["VAPID_SUBJECT"],
        public_key: ENV["VAPID_PUBLIC_KEY"],
        private_key: ENV["VAPID_PRIVATE_KEY"]
      }
    end
  end
end
