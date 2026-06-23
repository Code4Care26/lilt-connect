module Api
  # Supporter's participations. Exposed as a map { eventId => true } (boolean,
  # no approval lifecycle — Readme §3.3).
  class ParticipationsController < BaseController
    # GET /api/participations/mine  -> mockDb.participations.mine()
    def mine
      render json: Participation.map_for(current_supporter_id)
    end

    # PUT /api/participations/mine/:event_id  -> mockDb.participations.setJoined(...)
    def update
      joined = ActiveModel::Type::Boolean.new.cast(params[:joined])
      scope = Participation.where(supporter_id: current_supporter_id, event_id: params[:event_id])

      if joined
        scope.first_or_create!
      else
        scope.delete_all
      end

      render json: Participation.map_for(current_supporter_id)
    end
  end
end
