module Api
  # Web Push subscriptions for the current mock identity. The browser registers
  # its PushSubscription here so Rails can deliver background notifications
  # (PushNotifier). Complements gosse SSE, which only reaches foreground tabs.
  class PushSubscriptionsController < BaseController
    before_action :require_identity, only: %i[create destroy]

    # POST /api/push/subscriptions
    # Body: { subscription: { endpoint, keys: { p256dh, auth } } } (PushSubscription.toJSON).
    # Upsert on endpoint: re-subscribing updates keys and (re)binds to the caller.
    def create
      sub = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
      sub.assign_attributes(
        identity_id: current_identity_id,
        p256dh: subscription_params.dig(:keys, :p256dh),
        auth: subscription_params.dig(:keys, :auth)
      )
      sub.save!
      render json: { ok: true }, status: :ok
    end

    # DELETE /api/push/subscriptions  (body: { endpoint })
    # Logout cleanup: drop the caller's subscription for this device's endpoint.
    def destroy
      PushSubscription.for_identity(current_identity_id)
                      .where(endpoint: params[:endpoint])
                      .delete_all
      render json: true
    end

    # GET /api/push/vapid_public_key — the public half the browser needs to
    # subscribe (applicationServerKey). Safe to expose; the private key stays in ENV.
    def vapid_public_key
      render json: { publicKey: ENV["VAPID_PUBLIC_KEY"].to_s }
    end

    private

    def subscription_params
      params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
    end

    def require_identity
      return unless current_identity_id.empty?

      render json: { error: "identity required" }, status: :unprocessable_entity
    end
  end
end
