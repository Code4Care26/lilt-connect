require "digest/md5"

module Api
  # "Il tuo impatto" — motivational stats for the current volunteer's profile.
  #
  # Hybrid by design (the user's call): the numbers are seeded from the
  # volunteer's name (deterministic per identity, stable across restarts), BUT
  # they are derived from the REAL managed events — not arbitrary. The seeded RNG
  # picks a plausible subset of real events and how many editions of each the
  # volunteer attended; everything else is then a true function of that data:
  #
  #   hours  = Σ (event.duration_minutes × editions)   <- real durations
  #   areas  = distinct event.kind of the picked events <- real categories
  #   roles  = tally of the picked events' roles         <- real roles
  #   since  = earliest picked event's starts_at         <- real datetime
  #
  # Only the SELECTION (which events, how many editions) and the small candidatura
  # counters are random — the magnitudes come from data we actually manage. When
  # real per-volunteer history lands, swap the seeded pick for the volunteer's own
  # approved EventApplications; the shape and the math stay the same.
  class VolunteerStatsController < BaseController
    MONTHS = %w[
      gennaio febbraio marzo aprile maggio giugno
      luglio agosto settembre ottobre novembre dicembre
    ].freeze

    # GET /api/volunteer/stats
    def show
      rng = seeded_rng
      # Pool: events that actually happened/were real (a cancelled event donated
      # no hours). Each has a real starts_at + duration_minutes from the seed.
      pool = Event.where.not(status: "cancelled").where.not(duration_minutes: nil).to_a

      if pool.empty?
        return render json: empty_stats
      end

      # Seeded selection: which events, and how many editions of each (these events
      # recur, so "Tour della Prevenzione ×3" is plausible).
      picked = pool.shuffle(random: rng).first(rng.rand(2..pool.size))
      editions = picked.map { |event| [event, rng.rand(1..4)] }

      total_minutes = editions.sum { |event, n| event.duration_minutes * n }
      first_event = picked.map(&:starts_at).compact.min

      render json: {
        since: month_label(first_event),                 # earliest real starts_at
        impact: editions.sum { |_, n| n },                # lifetime participations (with repeats)
        hours: (total_minutes / 60.0).round,              # Σ real durations × editions
        decisive: picked.count { |e| e.as_api[:needsParticipants] }, # real "sotto il minimo"
        reliability: rng.rand(80..100),                   # no real attendance data yet
        counts: {
          approved: picked.size,                          # distinct events confirmed
          pending: rng.rand(0..2),
          waitlist: rng.rand(0..1),
          supporter: rng.rand(0..3),
        },
        areas: picked.map(&:kind).uniq,                   # distinct real Event.kind
        roles: picked.flat_map { |e| e.roles || [] }      # real roles, tallied
                     .tally
                     .sort_by { |_, count| -count }
                     .first(3)
                     .map { |label, count| { label: label, count: count } },
      }
    end

    private

    # Stable RNG seeded from the identity name. MD5 (not String#hash, which is
    # process-randomised) keeps the seed identical across restarts.
    def seeded_rng
      seed = Digest::MD5.hexdigest(current_volunteer_id)[0, 8].to_i(16)
      Random.new(seed)
    end

    def month_label(time)
      return "" unless time

      "#{MONTHS[time.month - 1]} #{time.year}"
    end

    # New volunteer with no real events behind them: an honest zero state (the
    # frontend shows a "candidati al tuo primo evento" empty state from these).
    def empty_stats
      {
        since: "",
        impact: 0,
        hours: 0,
        decisive: 0,
        reliability: 0,
        counts: { approved: 0, pending: 0, waitlist: 0, supporter: 0 },
        areas: [],
        roles: [],
      }
    end
  end
end
