require "test_helper"

# The "candidatura accettata" push: approving a volunteer's application notifies
# that volunteer on the same commit that already fires the SSE invalidation.
class EventApplicationPushTest < ActiveSupport::TestCase
  setup do
    Seeds.run! # provides events e1, e3, … (EventApplication belongs_to :event)
    @orig_pub = ENV["VAPID_PUBLIC_KEY"]
    @orig_priv = ENV["VAPID_PRIVATE_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "test-public"
    ENV["VAPID_PRIVATE_KEY"] = "test-private"
    PushSubscription.create!(identity_id: "anna vol", endpoint: "https://push/anna", p256dh: "k", auth: "a")
    @delivered = []
    PushNotifier.transport = ->(subscription, payload, _vapid) { @delivered << [subscription.identity_id, payload] }
  end

  teardown do
    @orig_pub.nil? ? ENV.delete("VAPID_PUBLIC_KEY") : ENV["VAPID_PUBLIC_KEY"] = @orig_pub
    @orig_priv.nil? ? ENV.delete("VAPID_PRIVATE_KEY") : ENV["VAPID_PRIVATE_KEY"] = @orig_priv
    PushNotifier.transport = nil
  end

  test "approving a pending candidatura pushes to the volunteer" do
    app = EventApplication.create!(volunteer_id: "anna vol", event_id: "e1", status: "pending")
    assert_empty @delivered, "creating a pending application must not push"

    app.update!(status: "approved")
    assert_equal 1, @delivered.size
    identity, payload = @delivered.first
    assert_equal "anna vol", identity
    assert_equal "/volunteer/events", JSON.parse(payload)["url"]
  end

  test "transitions to non-approved statuses do not push" do
    app = EventApplication.create!(volunteer_id: "anna vol", event_id: "e1", status: "pending")
    app.update!(status: "waitlist")
    assert_empty @delivered
  end

  test "touching a non-status field on an approved row does not re-push" do
    app = EventApplication.create!(volunteer_id: "anna vol", event_id: "e1", status: "approved")
    @delivered.clear
    app.update!(phone: "+39 000")
    assert_empty @delivered, "only a status transition into approved should push"
  end
end
