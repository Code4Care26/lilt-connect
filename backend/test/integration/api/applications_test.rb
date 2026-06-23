require "test_helper"

module Api
  class ApplicationsTest < ActionDispatch::IntegrationTest
    # The caller is identified by name (X-Identity-Id); the backend keys the
    # application rows by it. Seeds no longer pre-populate per-user state, so a
    # fresh identity starts empty.
    VOL = { "X-Identity-Id" => "giulia vol" }.freeze

    setup { Seeds.run! }

    test "GET /api/applications/mine starts empty for a fresh identity" do
      get "/api/applications/mine", headers: VOL
      assert_response :success
      assert_equal({}, JSON.parse(response.body))
    end

    test "PUT sets a new application status, then GET reflects it" do
      put "/api/applications/mine/e4", params: { status: "pending" }, as: :json, headers: VOL
      assert_response :success
      assert_equal "pending", JSON.parse(response.body)["e4"]

      get "/api/applications/mine", headers: VOL
      assert_equal({ "e4" => "pending" }, JSON.parse(response.body))
    end

    test "PUT with blank status removes the application" do
      put "/api/applications/mine/e1", params: { status: "approved" }, as: :json, headers: VOL
      put "/api/applications/mine/e1", params: { status: nil }, as: :json, headers: VOL
      assert_response :success
      assert_not JSON.parse(response.body).key?("e1")
    end

    test "applications are scoped per identity" do
      put "/api/applications/mine/e1", params: { status: "pending" }, as: :json, headers: VOL
      get "/api/applications/mine", headers: { "X-Identity-Id" => "luca vol" }
      assert_equal({}, JSON.parse(response.body))
    end
  end
end
