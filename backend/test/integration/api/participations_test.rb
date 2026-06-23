require "test_helper"

module Api
  class ParticipationsTest < ActionDispatch::IntegrationTest
    # Identified by name (X-Identity-Id). Seeds no longer pre-populate per-user
    # state, so a fresh supporter starts with no participations.
    SUP = { "X-Identity-Id" => "mario rossi" }.freeze

    setup { Seeds.run! }

    test "GET /api/participations/mine starts empty for a fresh identity" do
      get "/api/participations/mine", headers: SUP
      assert_response :success
      assert_equal({}, JSON.parse(response.body))
    end

    test "PUT joined:true adds a participation, then GET reflects it" do
      put "/api/participations/mine/e1", params: { joined: true }, as: :json, headers: SUP
      assert_response :success
      assert_equal true, JSON.parse(response.body)["e1"]

      get "/api/participations/mine", headers: SUP
      assert_equal({ "e1" => true }, JSON.parse(response.body))
    end

    test "PUT joined:false removes a participation" do
      put "/api/participations/mine/e3", params: { joined: true }, as: :json, headers: SUP
      put "/api/participations/mine/e3", params: { joined: false }, as: :json, headers: SUP
      assert_response :success
      assert_not JSON.parse(response.body).key?("e3")
    end
  end
end
