class PushSubscription < ApplicationRecord
  # A browser's Web Push subscription, bound to the current mock identity
  # (X-Identity-Id, a free-form name — Readme §10). Persisted so Rails can send
  # background notifications via VAPID (see PushNotifier). Complements the gosse
  # SSE channel, which only reaches foreground tabs.

  validates :identity_id, :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true

  scope :for_identity, ->(identity_id) { where(identity_id: identity_id) }

  # Shape WebPush.payload_send expects for the `message`'s subscription.
  def to_web_push
    { endpoint: endpoint, keys: { p256dh: p256dh, auth: auth } }
  end
end
