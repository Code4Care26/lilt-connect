class Event < ApplicationRecord
  STATUSES = %w[draft published cancelled].freeze
  DEFAULT_POSTER = "linear-gradient(135deg,#0D9488,#2DD4BF)".freeze

  # Volunteer applications to this event (the staff "manage applications" data).
  has_many :event_applications, foreign_key: :event_id, inverse_of: :event, dependent: :destroy

  # Realtime: notify open SSE clients that events changed (create/update/destroy).
  # Invalidation only — clients re-fetch via REST. A no-op when nobody is
  # connected. Seeds.run! uses delete_all/insert_all, which bypass callbacks, so
  # a reset does not stampede this (ResetController publishes a single `reset`).
  after_commit { Realtime.publish(type: "events.changed", id: id) }

  # Statuses that count as an active volunteer candidatura (a `supporter` is not
  # one; a `withdrawn` no longer counts but is still shown to staff).
  CANDIDATURE_STATUSES = %w[pending approved waitlist].freeze
  # Statuses shown in the staff "manage applications" screen (active + withdrawn).
  MANAGED_STATUSES = %w[pending approved waitlist withdrawn].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  # Contract key (camelCase) -> DB column. The single source of truth for both
  # reading (as_api) and writing (attrs_from_api). Keys not listed are ignored
  # on write (e.g. id is server-generated, counts are not client-settable).
  WRITE_KEYS = {
    "title" => :title, "kind" => :kind, "subtitle" => :subtitle,
    "dateLabel" => :date_label, "timeLabel" => :time_label,
    # Real schedule: the form sends an ISO `startsAt` so the event participates
    # in date ordering and the "past events" filter (see EventsController#index).
    "startsAt" => :starts_at, "durationMinutes" => :duration_minutes,
    "place" => :place, "address" => :address, "poster" => :poster,
    "icon" => :icon, "badge" => :badge, "badgeBg" => :badge_bg, "badgeFg" => :badge_fg,
    "description" => :description, "roles" => :roles, "slots" => :slots,
    "status" => :status, "reason" => :reason
  }.freeze

  # Serialize to the API contract. Keys are camelCase, all English (the frontend
  # mock's Italian keys `candidature`/`attesa` and the abbreviated `desc` were
  # renamed to applicationsCount/waitlistCount/description — the frontend will be
  # aligned to match). Keeping this in one place is the contract: request specs
  # assert these keys so drift fails loudly.
  def as_api
    applications_count = candidatures.size
    min_participants = min_participants_value
    missing = [min_participants - applications_count, 0].max
    {
      id: id,
      title: title,
      kind: kind,
      subtitle: subtitle,
      dateLabel: date_label,
      timeLabel: time_label,
      # Real schedule (alongside the display labels): enables hours/time-window math.
      startsAt: starts_at&.iso8601,
      durationMinutes: duration_minutes,
      place: place,
      address: address,
      poster: poster,
      icon: icon,
      badge: badge,
      badgeBg: badge_bg,
      badgeFg: badge_fg,
      description: description,
      roles: roles || [],
      slots: slots || {},
      # Live counts from the real volunteer applications (not the stored columns).
      applicationsCount: applications_count,
      waitlistCount: candidatures.count { |s| s == "waitlist" },
      # Volunteer "ingaggio": the minimum is derived from the slots (full capacity =
      # approved + available); the event still needs volunteers while active
      # candidatures are below it. needsParticipants gates on `published` so
      # volunteers are never invited to engage with drafts or cancelled events.
      minParticipants: min_participants,
      missingParticipants: missing,
      needsParticipants: status == "published" && missing.positive?,
      status: status,
      reason: reason
    }
  end

  # Minimum number of participants for the event, derived from the slots: the full
  # capacity (approved + available). No dedicated column — the threshold lives in
  # the slots, the single place capacity is expressed today.
  private def min_participants_value
    s = slots || {}
    s["approved"].to_i + s["available"].to_i
  end
  public

  # Statuses of this event's volunteer candidatures (excludes `supporter`).
  private def candidatures
    event_applications.where(status: CANDIDATURE_STATUSES).pluck(:status)
  end
  public

  # Translate a contract payload (camelCase keys) into column attributes.
  def self.attrs_from_api(data)
    data.to_h.each_with_object({}) do |(key, value), attrs|
      column = WRITE_KEYS[key.to_s]
      attrs[column] = value if column
    end
  end

  # Mirror frontend mockDb.create: generate a slug id and fill the same defaults.
  # Counts always start at 0 (not client-settable), reason is always nil.
  def self.create_from_api(data)
    attrs = attrs_from_api(data)
    create!(
      id: slug_id(attrs[:title]),
      title: attrs[:title],
      kind: attrs[:kind].presence || "Evento",
      subtitle: attrs[:subtitle] || "",
      date_label: attrs[:date_label] || "",
      time_label: attrs[:time_label] || "",
      starts_at: attrs[:starts_at],
      duration_minutes: attrs[:duration_minutes],
      place: attrs[:place] || "",
      address: attrs[:address].presence || attrs[:place] || "",
      poster: attrs[:poster].presence || DEFAULT_POSTER,
      icon: attrs[:icon].presence || "Sparkles",
      description: attrs[:description] || "",
      roles: attrs[:roles] || [],
      slots: attrs[:slots] || { "approved" => 0, "available" => 0 },
      applications_count: 0,
      waitlist_count: 0,
      status: attrs[:status].presence || "draft",
      reason: nil
    )
  end

  def update_from_api(patch)
    update!(self.class.attrs_from_api(patch))
  end

  # Mirror frontend mockDb.slugId: accent-stripped, non-alnum -> '-', max 24 chars,
  # suffixed with a running count so ids stay unique.
  def self.slug_id(title)
    base = title.to_s.downcase
                .unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
                .gsub(/[^a-z0-9]+/, "-")
                .gsub(/\A-|-\z/, "")
                .slice(0, 24)
    base = "nuovo" if base.blank?
    "ev-#{base}-#{count + 1}"
  end
end
