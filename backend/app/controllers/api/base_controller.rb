module Api
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

    private

    # Mock auth (Readme §10): no real login. The frontend sends a free-form name
    # as X-Identity-Id on every request; the role is derived from it (Identity).
    # A blank identity is the anonymous guest (treated as a supporter).
    def current_identity_id
      request.headers["X-Identity-Id"].to_s.strip
    end

    def current_role
      Identity.role_for(current_identity_id)
    end

    def staff?
      current_role == "staff"
    end

    # Back-compat shims for the /mine endpoints, which key rows by the caller's
    # id. Both now resolve to the single current identity.
    def current_volunteer_id
      current_identity_id
    end

    def current_supporter_id
      current_identity_id
    end

    def not_found
      render json: { error: "not_found" }, status: :not_found
    end

    def unprocessable(error)
      render json: { error: error.record.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
