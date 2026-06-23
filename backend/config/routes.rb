Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # API surface mirrors frontend/src/api/mockDb.js 1:1 (see backend/README.md).
  namespace :api do
    post "reset", to: "reset#create"

    # Magic-link login simulation: resolve a name to its role (see SessionsController).
    post "session", to: "sessions#create"

    resources :events, only: %i[index show create update] do
      resources :applicants, only: %i[index]
    end
    resources :applicants, only: %i[update destroy]

    # "mine" endpoints return a map keyed by eventId for the current mock user.
    get "applications/mine", to: "applications#mine"
    put "applications/mine/:event_id", to: "applications#update"

    get "participations/mine", to: "participations#mine"
    put "participations/mine/:event_id", to: "participations#update"

    # "Il tuo impatto": motivational stats for the current volunteer (placeholder
    # random data for now — see VolunteerStatsController).
    get "volunteer/stats", to: "volunteer_stats#show"

    # Console staff: triage + retention data. Hybrid (real events + generated
    # per-volunteer rows), same approach as volunteer/stats — see StaffDashboardController.
    get "staff/dashboard", to: "staff_dashboard#show"

    # Web Push: subscribe/unsubscribe the current device + expose the VAPID
    # public key. Background notifications complement the gosse SSE foreground channel.
    get "push/vapid_public_key", to: "push_subscriptions#vapid_public_key"
    post "push/subscriptions", to: "push_subscriptions#create"
    delete "push/subscriptions", to: "push_subscriptions#destroy"
  end
end
