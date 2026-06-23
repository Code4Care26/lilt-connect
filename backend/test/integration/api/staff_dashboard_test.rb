require "test_helper"

module Api
  # GET /api/staff/dashboard — the Console (staff) data.
  #
  # Hybrid like VolunteerStatsController: the event-anchored parts are REAL
  # (published events, capacity from slots, urgency from starts_at), the
  # per-volunteer parts are generated deterministically from a stable seed
  # (no event_applications are seeded). The contract here mirrors the shape the
  # frontend ConsoleView consumes — assert it so drift fails loudly.
  class StaffDashboardTest < ActionDispatch::IntegrationTest
    STAFF = { "X-Identity-Id" => "anna staff" }.freeze

    KPI_KEYS = %w[atRiskEvents pendingApplications oldestPendingDays atRiskVolunteers].freeze
    AT_RISK_KEYS = %w[id title kind dateLabel daysToStart min confirmed missing waitlistAvailable].freeze
    PENDING_KEYS = %w[id name initials color eventTitle waitingDays].freeze
    DORMANT_KEYS = %w[name initials color pastEvents lastActivityWeeks].freeze
    WITHDRAWAL_KEYS = %w[name initials color eventTitle daysAgo].freeze
    STUCK_KEYS = %w[name initials color eventTitle weeks].freeze
    RELIABILITY_KEYS = %w[name initials color pct approved withdrawn].freeze
    MATCH_KEYS = %w[id name initials color eventTitle eventNeeds eventId].freeze

    setup { Seeds.run! }

    def get_dashboard
      get "/api/staff/dashboard", headers: STAFF
      assert_response :success
      JSON.parse(response.body)
    end

    test "returns the kpis and the five sections with the exact contract keys" do
      body = get_dashboard

      assert_equal KPI_KEYS.sort, body["kpis"].keys.sort
      %w[atRiskEvents pendingApplications waitlistMatches].each do |section|
        assert_kind_of Array, body[section], "#{section} should be an array"
      end
      assert_equal %w[dormant recentWithdrawals reliability stuckWaitlist].sort,
                   body["volunteerHealth"].keys.sort
    end

    test "atRiskEvents are real published events below their minimum" do
      body = get_dashboard
      published_ids = Event.where(status: "published").pluck(:id)

      assert body["atRiskEvents"].any?, "expected at least one at-risk event from the seed"
      body["atRiskEvents"].each do |ev|
        assert_equal AT_RISK_KEYS.sort, ev.keys.sort
        assert_includes published_ids, ev["id"]
        assert ev["missing"].positive?, "#{ev['id']} should be missing volunteers"
        assert_equal ev["min"] - ev["confirmed"], ev["missing"]
        assert_kind_of Integer, ev["daysToStart"]
      end
    end

    test "every section row carries the keys ConsoleView expects" do
      body = get_dashboard
      h = body["volunteerHealth"]

      body["pendingApplications"].each { |r| assert_equal PENDING_KEYS.sort, r.keys.sort }
      h["dormant"].each { |r| assert_equal DORMANT_KEYS.sort, r.keys.sort }
      h["recentWithdrawals"].each { |r| assert_equal WITHDRAWAL_KEYS.sort, r.keys.sort }
      h["stuckWaitlist"].each { |r| assert_equal STUCK_KEYS.sort, r.keys.sort }
      h["reliability"].each { |r| assert_equal RELIABILITY_KEYS.sort, r.keys.sort }
      body["waitlistMatches"].each { |r| assert_equal MATCH_KEYS.sort, r.keys.sort }
    end

    test "kpis are consistent with the sections" do
      body = get_dashboard
      assert_equal body["atRiskEvents"].size, body["kpis"]["atRiskEvents"]
      assert_equal body["pendingApplications"].size, body["kpis"]["pendingApplications"]
      assert_equal body["pendingApplications"].map { |r| r["waitingDays"] }.max.to_i,
                   body["kpis"]["oldestPendingDays"]
      expected_at_risk = body["volunteerHealth"]["dormant"].size +
                         body["volunteerHealth"]["recentWithdrawals"].size
      assert_equal expected_at_risk, body["kpis"]["atRiskVolunteers"]
    end

    test "waitlistMatches reference real events that need volunteers" do
      body = get_dashboard
      event_ids = Event.pluck(:id)
      body["waitlistMatches"].each do |m|
        assert_includes event_ids, m["eventId"]
        assert m["eventNeeds"].positive?
      end
    end

    test "is deterministic: two requests return identical data" do
      first = get_dashboard
      second = get_dashboard
      assert_equal first, second
    end
  end
end
