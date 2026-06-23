require "test_helper"

module Api
  # Magic-link login simulation (Readme §10): the backend "authenticates" by
  # deriving the role from the submitted name and returns the resolved identity.
  # Login is immediate — there is no real link/email step.
  class SessionTest < ActionDispatch::IntegrationTest
    test "POST /api/session resolves a staff name" do
      post "/api/session", params: { name: "Anna Staff" }, as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "Anna Staff", body["name"]
      assert_equal "staff", body["role"]
      assert_equal "AS", body["initials"]
    end

    test "POST /api/session resolves a volunteer name" do
      post "/api/session", params: { name: "giulia vol" }, as: :json
      assert_response :success
      assert_equal "volunteer", JSON.parse(response.body)["role"]
    end

    test "POST /api/session resolves any other name to supporter" do
      post "/api/session", params: { name: "Mario Rossi" }, as: :json
      assert_response :success
      assert_equal "supporter", JSON.parse(response.body)["role"]
    end

    test "POST /api/session rejects a blank name" do
      post "/api/session", params: { name: "" }, as: :json
      assert_response :unprocessable_entity
    end
  end
end
