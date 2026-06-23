class CreateParticipations < ActiveRecord::Migration[8.0]
  def change
    # A supporter's participation in an event — a simple boolean (the row exists
    # or it doesn't), no approval lifecycle (Readme §3.3). Exposed as a map
    # (eventId -> true), never by row id.
    create_table :participations do |t|
      t.string :supporter_id, null: false
      t.string :event_id, null: false

      t.timestamps
    end

    add_index :participations, [:supporter_id, :event_id], unique: true
  end
end
