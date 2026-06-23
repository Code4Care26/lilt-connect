module Api
  # Staff "manage applications": the applicants of an event ARE the real
  # volunteer applications (event_applications), not a separate roster.
  # `supporter` rows are excluded — they are not volunteer candidatures.
  class ApplicantsController < BaseController
    # GET /api/events/:event_id/applicants
    # Includes `withdrawn` (shown in a dedicated section); excludes `supporter`.
    def index
      applications = EventApplication
        .where(event_id: params[:event_id], status: Event::MANAGED_STATUSES)
        .order(:created_at)
      render json: applications.map(&:as_applicant_api)
    end

    # PATCH /api/applicants/:id  -> approve / move to waitlist
    def update
      application = EventApplication.find(params[:id])
      application.update!(status: params[:status])
      render json: application.as_applicant_api
    end

    # DELETE /api/applicants/:id  -> reject (removes the application)
    def destroy
      EventApplication.find(params[:id]).destroy!
      render json: true
    end
  end
end
