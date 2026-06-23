module Api
  # Magic-link login simulation (Readme §10): no real auth. We "authenticate" by
  # deriving the role from the submitted name and returning the resolved
  # identity. Login is immediate — there is no actual email/link step. The
  # frontend then sends the name as X-Identity-Id on every request.
  class SessionsController < BaseController
    # POST /api/session  -> { name, role, initials }
    def create
      name = params[:name].to_s.strip
      return render json: { error: "name_required" }, status: :unprocessable_entity if name.blank?

      render json: {
        name: name,
        role: Identity.role_for(name),
        initials: Identity.initials_for(name)
      }
    end
  end
end
