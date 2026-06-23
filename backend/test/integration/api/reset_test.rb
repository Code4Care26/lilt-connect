require "test_helper"

module Api
  class ResetTest < ActionDispatch::IntegrationTest
    setup { Seeds.run! }

    test "POST /api/reset restores the seed and wipes per-user state after mutations" do
      Event.find("e2").update!(status: "published")
      EventApplication.create!(volunteer_id: "giulia vol", event_id: "e1", status: "pending")
      Participation.create!(supporter_id: "mario", event_id: "e3")

      post "/api/reset"
      assert_response :success
      assert_equal true, JSON.parse(response.body)

      assert_equal 5, Event.count
      assert_equal "draft", Event.find("e2").status
      # Per-user state is not seeded: reset leaves it empty.
      assert_equal 0, EventApplication.count
      assert_equal 0, Participation.count
    end
  end
end
