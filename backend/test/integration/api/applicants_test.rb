require "test_helper"

module Api
  # The staff "manage applications" view is backed by real volunteer
  # applications (event_applications), exposed under the /applicants endpoints.
  class ApplicantsTest < ActionDispatch::IntegrationTest
    APPLICANT_KEYS = %w[id name initials color pref status eventId phone email].freeze

    setup do
      Seeds.run!
      @pending = EventApplication.create!(volunteer_id: "giulia vol", event_id: "e1", status: "pending")
      EventApplication.create!(volunteer_id: "luca vol", event_id: "e1", status: "approved")
      EventApplication.create!(volunteer_id: "sara vol", event_id: "e1", status: "withdrawn") # ritirato: still shown
      EventApplication.create!(volunteer_id: "mario", event_id: "e1", status: "supporter") # not a candidatura
      EventApplication.create!(volunteer_id: "anna vol", event_id: "e3", status: "pending") # other event
    end

    test "GET /api/events/:event_id/applicants lists active + withdrawn, excluding supporters" do
      get "/api/events/e1/applicants"
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 3, body.size # pending + approved + withdrawn (supporter & other event excluded)
      assert_equal APPLICANT_KEYS.sort, body.first.keys.sort
      names = body.map { |a| a["name"] }
      assert_includes names, "sara vol"
      assert_not_includes names, "mario"
    end

    test "derives initials from the volunteer name" do
      get "/api/events/e1/applicants"
      giulia = JSON.parse(response.body).find { |a| a["name"] == "giulia vol" }
      assert_equal "GV", giulia["initials"]
      assert_equal "e1", giulia["eventId"]
    end

    test "exposes deterministic mock contact details for direct contact" do
      get "/api/events/e1/applicants"
      giulia = JSON.parse(response.body).find { |a| a["name"] == "giulia vol" }
      assert_equal Identity.phone_for("giulia vol"), giulia["phone"]
      assert_equal Identity.email_for("giulia vol"), giulia["email"]
      assert_match(/@/, giulia["email"])
      # Persisted on create, not recomputed on read.
      assert_equal giulia["phone"], @pending.reload.phone
    end

    test "PATCH /api/applicants/:id updates the application status" do
      patch "/api/applicants/#{@pending.id}", params: { status: "approved" }, as: :json
      assert_response :success
      assert_equal "approved", JSON.parse(response.body)["status"]
      assert_equal "approved", @pending.reload.status
    end

    test "DELETE /api/applicants/:id removes the application and returns true" do
      delete "/api/applicants/#{@pending.id}"
      assert_response :success
      assert_equal true, JSON.parse(response.body)
      assert_not EventApplication.exists?(@pending.id)
    end
  end
end
