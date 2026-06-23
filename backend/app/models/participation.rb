class Participation < ApplicationRecord
  # Realtime: invalidation only — clients re-fetch via REST. No-op when nobody
  # is connected (see Realtime / Api::StreamController).
  after_commit { Realtime.publish(type: "participations.changed", eventId: event_id) }

  validates :supporter_id, :event_id, presence: true
  validates :event_id, uniqueness: { scope: :supporter_id }

  # The contract returns these as a map { eventId => true } for the current
  # supporter — see Api::ParticipationsController.
  def self.map_for(supporter_id)
    where(supporter_id: supporter_id).pluck(:event_id).index_with { true }
  end
end
