require "digest/md5"

module Api
  # GET /api/staff/dashboard — data for the staff Console (triage + retention).
  #
  # Hybrid, exactly like VolunteerStatsController ("Il tuo impatto"): the parts
  # anchored to events are REAL (published events, capacity from slots, urgency
  # from starts_at), while the per-volunteer parts (pending, dormant, withdrawals,
  # stuck waitlist, reliability) are GENERATED from a stable seed — no
  # event_applications are seeded, so a purely-real endpoint would be empty.
  #
  # When real per-volunteer history lands, swap the generated rows for
  # aggregations over event_applications grouped by volunteer_id; the output
  # shape and the frontend (ConsoleView) stay the same.
  class StaffDashboardController < BaseController
    # A fixed, plausible volunteer roster. Names are the single input: initials
    # and avatar colour are derived from them via Identity (same as real applicants).
    ROSTER = [
      "Giulia Bianchi", "Marco Rossi", "Sara Conte", "Luca Ferri", "Elena Mauro",
      "Paolo Greco", "Chiara Rinaldi", "Davide Lupo", "Anna Verdi", "Federico Sala",
      "Marta Neri", "Giorgio Pace", "Ilaria Costa", "Matteo Riva", "Sofia Gallo",
    ].freeze

    # GET /api/staff/dashboard
    def show
      rng = seeded_rng
      published = Event.where(status: "published").order(:starts_at).to_a
      names = ROSTER.shuffle(random: rng) # stable shuffle; sections take disjoint slices

      at_risk = build_at_risk(published, rng)
      pending = build_pending(published, names.shift(rng.rand(4..6)), rng)
      health  = build_health(published, names, rng)
      matches = build_matches(at_risk, rng)

      render json: {
        kpis: {
          atRiskEvents: at_risk.size,
          pendingApplications: pending.size,
          oldestPendingDays: pending.map { |p| p[:waitingDays] }.max.to_i,
          atRiskVolunteers: health[:dormant].size + health[:recentWithdrawals].size,
        },
        atRiskEvents: at_risk,
        pendingApplications: pending,
        volunteerHealth: health,
        waitlistMatches: matches,
      }
    end

    private

    # Stable across restarts AND requests: a constant seed (a staff console has no
    # single subject to seed from). MD5 avoids String#hash's per-process randomisation.
    def seeded_rng
      Random.new(Digest::MD5.hexdigest("lilt-staff-dashboard")[0, 8].to_i(16))
    end

    # Name -> the avatar fields the frontend expects (mirrors EventApplication#as_applicant_api).
    def person(name)
      { name: name, initials: Identity.initials_for(name), color: Identity.color_for(name) }
    end

    # A. Eventi a rischio — REAL published events, under their (real) minimum. The
    # minimum comes from slots; `confirmed` is seeded below it so missing > 0 (the
    # console exists precisely for understaffed events). daysToStart is real from
    # starts_at; the frontend sorts by urgency = missing / daysToStart.
    def build_at_risk(published, rng)
      published.map do |event|
        min = min_for(event)
        next if min.zero?

        confirmed = (min * rng.rand(0.40..0.92)).floor # always below min => missing > 0
        {
          id: event.id,
          title: event.title,
          kind: event.kind,
          dateLabel: event.date_label,
          daysToStart: days_to_start(event, rng),
          min: min,
          confirmed: confirmed,
          missing: min - confirmed,
          waitlistAvailable: rng.rand(2..5),
        }
      end.compact
    end

    # B. In attesa di risposta — generated volunteers waiting on real events,
    # oldest first (responsiveness is the retention lever the section is about).
    def build_pending(published, names, rng)
      names.each_with_index.map do |name, i|
        person(name).merge(
          id: i + 1,
          eventTitle: title_sample(published, rng),
          waitingDays: rng.rand(1..7),
        )
      end.sort_by { |p| -p[:waitingDays] }
    end

    # C. Salute dei volontari — the retention core. Disjoint slices of the roster
    # so the same person isn't in two buckets at once.
    def build_health(published, names, rng)
      dormant = names.shift(2).map { |n| person(n).merge(pastEvents: rng.rand(3..8), lastActivityWeeks: rng.rand(4..8)) }
      withdrawals = names.shift(2).map { |n| person(n).merge(eventTitle: title_sample(published, rng), daysAgo: rng.rand(1..10)) }
      stuck = names.shift(2).map { |n| person(n).merge(eventTitle: title_sample(published, rng), weeks: rng.rand(2..5)) }
      reliability = names.shift(3).map do |n|
        approved = rng.rand(3..20)
        withdrawn = rng.rand(0..4)
        person(n).merge(approved: approved, withdrawn: withdrawn, pct: (approved * 100.0 / (approved + withdrawn)).round)
      end.sort_by { |r| -r[:pct] }

      { dormant: dormant, recentWithdrawals: withdrawals, stuckWaitlist: stuck, reliability: reliability }
    end

    # D. Riserva da valorizzare — waitlisted volunteers matched to real at-risk
    # events (eventNeeds = the event's real shortfall). Closes A and C in one tap.
    def build_matches(at_risk, rng)
      pool = ROSTER.shuffle(random: rng)
      id = 0
      at_risk.flat_map do |ev|
        pool.shift(rng.rand(1..2)).map do |name|
          id += 1
          person(name).merge(id: id, eventTitle: ev[:title], eventNeeds: ev[:missing], eventId: ev[:id])
        end
      end
    end

    # Minimum participants = full capacity from slots (approved + available),
    # the same derivation Event#as_api uses for the volunteer "ingaggio" badge.
    def min_for(event)
      slots = event.slots || {}
      slots["approved"].to_i + slots["available"].to_i
    end

    def days_to_start(event, rng)
      return rng.rand(3..20) unless event.starts_at

      ((event.starts_at - Time.current) / 1.day).ceil
    end

    def title_sample(published, rng)
      return "un evento" if published.empty?

      published[rng.rand(published.size)].title
    end
  end
end
