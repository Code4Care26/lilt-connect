class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :push_subscriptions do |t|
      # Mock identity (Readme §10): the free-form name sent as X-Identity-Id.
      t.string :identity_id, null: false
      # Web Push subscription fields (PushSubscription.toJSON from the browser).
      t.string :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false

      t.timestamps
    end

    # One row per browser subscription; re-subscribing upserts on the endpoint.
    add_index :push_subscriptions, :endpoint, unique: true
    # PushNotifier looks up all subscriptions of a target identity.
    add_index :push_subscriptions, :identity_id
  end
end
