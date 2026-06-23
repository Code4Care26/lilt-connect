module Api
  # Volunteer's per-event application status. Exposed as a map { eventId => status }.
  class ApplicationsController < BaseController
    # GET /api/applications/mine  -> mockDb.applications.mine()
    def mine
      render json: EventApplication.map_for(current_volunteer_id)
    end

    # PUT /api/applications/mine/:event_id  -> mockDb.applications.setStatus(...)
    # A null/blank status removes the application (mirrors the mock's delete).
    def update
      status = params[:status]
      scope = EventApplication.where(volunteer_id: current_volunteer_id, event_id: params[:event_id])

      if status.blank?
        scope.delete_all
      else
        record = scope.first_or_initialize
        record.update!(status: status)
      end

      render json: EventApplication.map_for(current_volunteer_id)
    end
  end
end
