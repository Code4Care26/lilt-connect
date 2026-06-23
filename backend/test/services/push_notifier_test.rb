require "test_helper"

class PushNotifierTest < ActiveSupport::TestCase
  setup do
    @orig_pub = ENV["VAPID_PUBLIC_KEY"]
    @orig_priv = ENV["VAPID_PRIVATE_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "test-public"
    ENV["VAPID_PRIVATE_KEY"] = "test-private"
  end

  teardown do
    restore("VAPID_PUBLIC_KEY", @orig_pub)
    restore("VAPID_PRIVATE_KEY", @orig_priv)
    PushNotifier.transport = nil # back to the real WebPush sender
  end

  def sub_for(identity, endpoint)
    PushSubscription.create!(identity_id: identity, endpoint: endpoint, p256dh: "k", auth: "a")
  end

  test "no-op (returns nil, no delivery) when VAPID keys are unset" do
    ENV.delete("VAPID_PUBLIC_KEY")
    sub_for("Anna", "https://push/a")
    called = false
    PushNotifier.transport = ->(*) { called = true }

    assert_nil PushNotifier.notify("Anna", title: "Hi")
    refute called, "must not deliver when unconfigured"
  end

  test "delivers one encrypted message per subscription of the identity" do
    sub_for("Anna", "https://push/a")
    sub_for("Anna", "https://push/b")
    sub_for("Marco", "https://push/c") # other identity, must be skipped
    delivered = []
    PushNotifier.transport = ->(subscription, payload, _vapid) { delivered << [subscription.endpoint, payload] }

    count = PushNotifier.notify("Anna", title: "Candidatura accettata", body: "Sei dentro!", url: "/volunteer/events")
    assert_equal 2, count
    assert_equal %w[https://push/a https://push/b].sort, delivered.map(&:first).sort
    payload = JSON.parse(delivered.first.last)
    assert_equal "Candidatura accettata", payload["title"]
    assert_equal "Sei dentro!", payload["body"]
    assert_equal "/volunteer/events", payload["url"]
  end

  test "prunes subscriptions that the push service reports as gone (404/410)" do
    sub_for("Anna", "https://push/dead")
    fake_resp = Struct.new(:body).new("410 Gone")
    PushNotifier.transport = ->(*) { raise WebPush::ExpiredSubscription.new(fake_resp, "host") }

    assert_nothing_raised { PushNotifier.notify("Anna", title: "Hi") }
    assert_equal 0, PushSubscription.for_identity("Anna").count, "expired subscription must be pruned"
  end

  test "a transient delivery error is swallowed and does NOT prune the subscription" do
    sub_for("Anna", "https://push/flaky")
    PushNotifier.transport = ->(*) { raise "network blip" }

    assert_nothing_raised { PushNotifier.notify("Anna", title: "Hi") }
    assert_equal 1, PushSubscription.for_identity("Anna").count, "transient errors must not prune"
  end

  private

  def restore(key, value)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end
end
