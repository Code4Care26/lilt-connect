class EventApplication < ApplicationRecord
  # The volunteer's per-event application status. Values mirror the mock's
  # VOLUNTEER_INITIAL_APP (frontend/src/data/seed.js:166): besides the applicant
  # lifecycle states, a volunteer may participate as `supporter`.
  # `withdrawn` (ritirato): the volunteer pulled out. Kept as a record (not
  # deleted) so the staff and the volunteer both still see it.
  STATUSES = %w[pending approved waitlist supporter withdrawn].freeze

  belongs_to :event, inverse_of: :event_applications

  # Realtime: a candidatura change also moves the event's derived counts/slots,
  # so clients re-fetch on this (invalidation only). No-op without subscribers.
  after_commit { Realtime.publish(type: "applications.changed", eventId: event_id) }

  # Web Push (background): when a candidatura is *accepted*, notify the volunteer
  # even with the app closed — the complement to the SSE invalidation above.
  # Gated on an actual transition into `approved` so we push once, not on every
  # save. Best-effort: PushNotifier swallows delivery errors (never fails the save).
  after_commit :notify_volunteer_if_approved, on: %i[create update]

  validates :volunteer_id, :event_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :event_id, uniqueness: { scope: :volunteer_id }

  # Mock contact details so staff can reach the volunteer directly (call /
  # WhatsApp / email). No real users table yet (Readme §10): derive them
  # deterministically from the name on create, leaving any explicit value alone.
  before_validation :assign_mock_contacts, on: :create

  # The contract returns these as a map { eventId => status } for the current
  # volunteer — see Api::ApplicationsController.
  def self.map_for(volunteer_id)
    where(volunteer_id: volunteer_id).pluck(:event_id, :status).to_h
  end

  # Shape consumed by the staff "manage applications" screen (Api::ApplicantsController).
  # The applicant IS the volunteer identity (name); initials/colour are derived
  # from it. No preferred-role field — volunteers apply with a single tap.
  def as_applicant_api
    {
      id: id,
      name: volunteer_id,
      initials: Identity.initials_for(volunteer_id),
      color: Identity.color_for(volunteer_id),
      pref: nil,
      status: status,
      eventId: event_id,
      # Direct-contact details for the staff roster (mock — see assign_mock_contacts).
      phone: phone,
      email: email
    }
  end

  private

  def notify_volunteer_if_approved
    return unless saved_change_to_status? && status == "approved"

    PushNotifier.notify(
      volunteer_id,
      title: "Candidatura accettata 🎉",
      body: "Sei stato accettato come volontario. Tocca per vedere i dettagli.",
      url: "/volunteer/events"
    )
  end

  def assign_mock_contacts
    self.phone ||= Identity.phone_for(volunteer_id)
    self.email ||= Identity.email_for(volunteer_id)
  end
end
