require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      identity_id: "Anna",
      endpoint: "https://push.example.com/abc",
      p256dh: "p256dh-key",
      auth: "auth-secret"
    }.merge(overrides)
  end

  test "valid with all required attributes" do
    assert PushSubscription.new(valid_attrs).valid?
  end

  test "requires identity_id, endpoint, p256dh and auth" do
    %i[identity_id endpoint p256dh auth].each do |field|
      sub = PushSubscription.new(valid_attrs(field => ""))
      assert sub.invalid?, "expected #{field} to be required"
      assert sub.errors.key?(field)
    end
  end

  test "endpoint is unique (the same browser must not register twice)" do
    PushSubscription.create!(valid_attrs)
    dup = PushSubscription.new(valid_attrs(identity_id: "Marco"))
    assert dup.invalid?
    assert dup.errors.key?(:endpoint)
  end

  test "for_identity scopes to a single identity" do
    PushSubscription.create!(valid_attrs(identity_id: "Anna", endpoint: "https://push/a"))
    PushSubscription.create!(valid_attrs(identity_id: "Anna", endpoint: "https://push/b"))
    PushSubscription.create!(valid_attrs(identity_id: "Marco", endpoint: "https://push/c"))

    assert_equal 2, PushSubscription.for_identity("Anna").count
    assert_equal %w[https://push/a https://push/b].sort,
                 PushSubscription.for_identity("Anna").pluck(:endpoint).sort
  end
end
