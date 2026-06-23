module Api
  class EventsController < BaseController
    # GET /api/events  -> mockDb.events.list()
    # Role-aware: drafts are visible only to staff (Readme §10). Everyone else
    # (volunteer / supporter / anonymous guest) sees published + cancelled.
    # Public listings also hide events whose date has passed and order the rest
    # soonest-first; staff keep seeing every event (incl. past ones) so they can
    # still edit/export them. Events without a real `starts_at` (e.g. drafts
    # created from the form) are never treated as past and sort last.
    def index
      scope = staff? ? Event.all : Event.where.not(status: "draft")
      unless staff?
        scope = scope.where("starts_at >= ? OR starts_at IS NULL", Time.current.beginning_of_day)
      end
      ordered = scope.order(Arel.sql("starts_at ASC NULLS LAST")).order(:created_at)
      render json: ordered.map(&:as_api)
    end

    # GET /api/events/:id  -> mockDb.events.get(id); returns null when missing.
    def show
      event = Event.find_by(id: params[:id])
      render json: event&.as_api
    end

    # POST /api/events  -> mockDb.events.create(data)
    def create
      event = Event.create_from_api(event_params)
      render json: event.as_api, status: :created
    end

    # PATCH /api/events/:id  -> mockDb.events.update(id, patch)
    def update
      event = Event.find(params[:id])
      event.update_from_api(event_params)
      render json: event.as_api
    end

    private

    def event_params
      scalar_keys = Event::WRITE_KEYS.keys - %w[roles slots]
      params.permit(*scalar_keys, roles: [], slots: {}).to_h
    end
  end
end
