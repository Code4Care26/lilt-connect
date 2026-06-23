require "test_helper"

module Api
  # Mock auth (Readme §10): every request carries X-Identity-Id (a free-form
  # name). The backend derives the role from the name on each request — there is
  # no real login. We probe the behaviour through /api/events, whose result set
  # is role-sensitive (staff sees drafts, others don't).
  class IdentityTest < ActionDispatch::IntegrationTest
    setup { Seeds.run! }

    def event_ids(headers = {})
      get "/api/events", headers: headers
      assert_response :success
      JSON.parse(response.body).map { |e| e["id"] }
    end

    test "a name ending in 'staff' is a staff and sees every event, incl. drafts" do
      assert_equal 5, event_ids("X-Identity-Id" => "anna staff").size
    end

    test "a name ending in 'vol' is a volunteer and never sees drafts" do
      assert_equal %w[e1 e3 e5], event_ids("X-Identity-Id" => "giulia vol").sort
    end

    test "any other name is a supporter and never sees drafts" do
      assert_equal %w[e1 e3 e5], event_ids("X-Identity-Id" => "mario rossi").sort
    end

    test "no identity (anonymous guest) is treated as a supporter" do
      assert_equal %w[e1 e3 e5], event_ids.sort
    end

    test "role derivation is case-insensitive and ignores surrounding space" do
      assert_equal 5, event_ids("X-Identity-Id" => "  Anna STAFF  ").size
    end
  end
end
