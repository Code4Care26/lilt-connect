require "test_helper"

module Api
  class EventsTest < ActionDispatch::IntegrationTest
    EVENT_KEYS = %w[
      id title kind subtitle dateLabel timeLabel startsAt durationMinutes
      place address poster icon
      badge badgeBg badgeFg description roles slots applicationsCount
      waitlistCount minParticipants missingParticipants needsParticipants
      status reason
    ].freeze

    # A staff identity sees every event (incl. drafts); role-based filtering is
    # covered in identity_test.rb.
    STAFF = { "X-Identity-Id" => "anna staff" }.freeze

    setup { Seeds.run! }

    test "GET /api/events returns all events with the exact contract keys" do
      get "/api/events", headers: STAFF
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 5, body.size
      e1 = body.find { |e| e["id"] == "e1" }
      assert_equal EVENT_KEYS.sort, e1.keys.sort
      assert_equal "Tour della Prevenzione", e1["title"]
      assert_equal({ "approved" => 8, "available" => 3 }, e1["slots"])
      # Counts are live from real applications; none seeded -> 0.
      assert_equal 0, e1["applicationsCount"]
      assert_equal 0, e1["waitlistCount"]
      assert_kind_of Array, e1["roles"]
    end

    test "applicationsCount/waitlistCount reflect real volunteer applications (supporters excluded)" do
      EventApplication.create!(volunteer_id: "giulia vol", event_id: "e1", status: "pending")
      EventApplication.create!(volunteer_id: "luca vol", event_id: "e1", status: "approved")
      EventApplication.create!(volunteer_id: "sara vol", event_id: "e1", status: "waitlist")
      EventApplication.create!(volunteer_id: "tom", event_id: "e1", status: "supporter") # excluded
      EventApplication.create!(volunteer_id: "elia vol", event_id: "e1", status: "withdrawn") # excluded

      get "/api/events/e1"
      body = JSON.parse(response.body)
      assert_equal 3, body["applicationsCount"] # pending + approved + waitlist (supporter & withdrawn excluded)
      assert_equal 1, body["waitlistCount"]
    end

    # Volunteer "ingaggio": minParticipants is derived from the slots (approved +
    # available = full capacity); the event still needs volunteers while active
    # candidatures (applicationsCount) are below it. needsParticipants gates on a
    # published status so volunteers are never nagged about drafts/cancelled events.
    test "engagement fields are derived from slots and live candidatures" do
      # e1: slots approved 8 + available 3 => minParticipants 11. Fresh seed has 0
      # candidatures, so the full minimum is still missing and help is needed.
      get "/api/events/e1", headers: STAFF
      e1 = JSON.parse(response.body)
      assert_equal 11, e1["minParticipants"]
      assert_equal 11, e1["missingParticipants"]
      assert_equal true, e1["needsParticipants"]

      # Add active candidatures up to (but below) the minimum: still needs people.
      9.times { |i| EventApplication.create!(volunteer_id: "v#{i} vol", event_id: "e1", status: "pending") }
      get "/api/events/e1", headers: STAFF
      e1 = JSON.parse(response.body)
      assert_equal 9, e1["applicationsCount"]
      assert_equal 2, e1["missingParticipants"]
      assert_equal true, e1["needsParticipants"]

      # Reaching the minimum clears the engagement flag.
      EventApplication.create!(volunteer_id: "v9 vol", event_id: "e1", status: "approved")
      EventApplication.create!(volunteer_id: "v10 vol", event_id: "e1", status: "approved")
      get "/api/events/e1", headers: STAFF
      e1 = JSON.parse(response.body)
      assert_equal 11, e1["applicationsCount"]
      assert_equal 0, e1["missingParticipants"]
      assert_equal false, e1["needsParticipants"]
    end

    test "needsParticipants is false for a non-published event even below minimum" do
      # e5 is cancelled with slots 2+2 => min 4 and 0 candidatures: below minimum,
      # but volunteers must not be invited to engage with it.
      get "/api/events/e5", headers: STAFF
      e5 = JSON.parse(response.body)
      assert_equal 4, e5["minParticipants"]
      assert_equal 4, e5["missingParticipants"]
      assert_equal false, e5["needsParticipants"]
    end

    test "GET /api/events/:id returns the event" do
      get "/api/events/e5"
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "cancelled", body["status"]
      assert_equal "Adesioni insufficienti", body["reason"]
    end

    test "GET /api/events/:id returns null when missing" do
      get "/api/events/nope"
      assert_response :success
      assert_nil JSON.parse(response.body)
    end

    test "POST /api/events creates with a slug id and mock defaults" do
      post "/api/events", params: { title: "Nuova Festa", kind: "Raccolta fondi" }, as: :json
      assert_response :created
      body = JSON.parse(response.body)
      assert_match(/\Aev-nuova-festa-\d+\z/, body["id"])
      assert_equal "Raccolta fondi", body["kind"]
      assert_equal "draft", body["status"]
      assert_equal 0, body["applicationsCount"]
      assert_equal({ "approved" => 0, "available" => 0 }, body["slots"])
      assert_equal 6, Event.count
    end

    test "POST /api/events with slots drives minParticipants for the volunteer badge" do
      post "/api/events",
           params: { title: "Open day", status: "published", slots: { approved: 0, available: 10 } },
           as: :json
      assert_response :created
      body = JSON.parse(response.body)
      assert_equal({ "approved" => 0, "available" => 10 }, body["slots"])
      assert_equal 10, body["minParticipants"]
      assert_equal 10, body["missingParticipants"]
      assert_equal true, body["needsParticipants"]
    end

    test "PATCH /api/events/:id applies a partial update" do
      patch "/api/events/e2", params: { status: "published" }, as: :json
      assert_response :success
      assert_equal "published", JSON.parse(response.body)["status"]
      assert_equal "published", Event.find("e2").status
    end

    # The create/edit form sends a real startsAt so UI-made events take part in
    # the date ordering and the past-events filter.
    test "POST /api/events persists a real startsAt from the form" do
      starts = 5.days.from_now
      post "/api/events", params: { title: "Con data", status: "published", startsAt: starts.iso8601 }, as: :json
      assert_response :created
      body = JSON.parse(response.body)
      assert_not_nil body["startsAt"]
      assert_not_nil Event.find(body["id"]).starts_at
      # Future + published => visible to a non-staff caller.
      get "/api/events"
      assert_includes JSON.parse(response.body).map { |e| e["id"] }, body["id"]
    end

    test "PATCH /api/events/:id can set startsAt" do
      patch "/api/events/e2", params: { startsAt: 10.days.from_now.iso8601 }, as: :json
      assert_response :success
      assert_not_nil JSON.parse(response.body)["startsAt"]
      assert_not_nil Event.find("e2").starts_at
    end

    # Public listings (non-staff) drop events whose date is in the past and order
    # the upcoming ones soonest-first; events without a real start date sort last
    # and are never treated as past. Dates are relative to Time.current so the
    # test does not depend on the seed's hardcoded calendar dates.
    test "GET /api/events hides past events and orders upcoming soonest-first for non-staff" do
      Event.delete_all
      Event.create!(id: "p1", title: "Passato", status: "published", starts_at: 3.days.ago)
      Event.create!(id: "f2", title: "Tra due settimane", status: "published", starts_at: 14.days.from_now)
      Event.create!(id: "f1", title: "Domani", status: "published", starts_at: 1.day.from_now)
      Event.create!(id: "nd", title: "Senza data", status: "published", starts_at: nil)

      get "/api/events" # default identity => supporter (non-staff)
      assert_response :success
      ids = JSON.parse(response.body).map { |e| e["id"] }
      assert_not_includes ids, "p1"     # past hidden
      assert_equal %w[f1 f2 nd], ids    # soonest first, no-date last
    end

    test "GET /api/events keeps past events visible for staff" do
      Event.delete_all
      Event.create!(id: "p1", title: "Passato", status: "published", starts_at: 3.days.ago)

      get "/api/events", headers: STAFF
      assert_includes JSON.parse(response.body).map { |e| e["id"] }, "p1"
    end
  end
end
