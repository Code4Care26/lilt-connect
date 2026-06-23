require "test_helper"

module Api
  class PushSubscriptionsTest < ActionDispatch::IntegrationTest
    SUB = {
      endpoint: "https://push.example.com/anna",
      keys: { p256dh: "p256dh-anna", auth: "auth-anna" }
    }.freeze

    def headers(identity = "Anna")
      { "X-Identity-Id" => identity }
    end

    test "POST creates a subscription bound to the current identity" do
      assert_difference -> { PushSubscription.count }, 1 do
        post "/api/push/subscriptions", params: { subscription: SUB }, headers: headers, as: :json
      end
      assert_response :success
      sub = PushSubscription.find_by(endpoint: SUB[:endpoint])
      assert_equal "Anna", sub.identity_id
      assert_equal "p256dh-anna", sub.p256dh
      assert_equal "auth-anna", sub.auth
    end

    test "POST is idempotent: re-subscribing the same endpoint upserts, not duplicates" do
      post "/api/push/subscriptions", params: { subscription: SUB }, headers: headers, as: :json
      assert_difference -> { PushSubscription.count }, 0 do
        post "/api/push/subscriptions",
             params: { subscription: SUB.merge(keys: { p256dh: "new-key", auth: "new-auth" }) },
             headers: headers, as: :json
      end
      assert_response :success
      sub = PushSubscription.find_by(endpoint: SUB[:endpoint])
      assert_equal "new-key", sub.p256dh
    end

    test "POST re-binds an endpoint to the new identity (identity changed on the device)" do
      post "/api/push/subscriptions", params: { subscription: SUB }, headers: headers("Anna"), as: :json
      post "/api/push/subscriptions", params: { subscription: SUB }, headers: headers("Marco"), as: :json
      assert_equal "Marco", PushSubscription.find_by(endpoint: SUB[:endpoint]).identity_id
    end

    test "POST without an identity is rejected" do
      post "/api/push/subscriptions", params: { subscription: SUB }, headers: { "X-Identity-Id" => "" }, as: :json
      assert_response :unprocessable_entity
      assert_equal 0, PushSubscription.count
    end

    test "DELETE removes the caller's subscription for the given endpoint" do
      PushSubscription.create!(identity_id: "Anna", endpoint: SUB[:endpoint], p256dh: "k", auth: "a")
      assert_difference -> { PushSubscription.count }, -1 do
        delete "/api/push/subscriptions", params: { endpoint: SUB[:endpoint] }, headers: headers, as: :json
      end
      assert_response :success
    end

    test "DELETE only touches the caller's own subscriptions" do
      PushSubscription.create!(identity_id: "Marco", endpoint: SUB[:endpoint], p256dh: "k", auth: "a")
      delete "/api/push/subscriptions", params: { endpoint: SUB[:endpoint] }, headers: headers("Anna"), as: :json
      assert PushSubscription.exists?(endpoint: SUB[:endpoint]), "Marco's subscription must survive Anna's delete"
    end

    test "GET vapid_public_key returns the configured key" do
      orig = ENV["VAPID_PUBLIC_KEY"]
      ENV["VAPID_PUBLIC_KEY"] = "BTestPublicKey"
      get "/api/push/vapid_public_key"
      assert_response :success
      assert_equal "BTestPublicKey", JSON.parse(response.body)["publicKey"]
    ensure
      orig.nil? ? ENV.delete("VAPID_PUBLIC_KEY") : ENV["VAPID_PUBLIC_KEY"] = orig
    end
  end
end
