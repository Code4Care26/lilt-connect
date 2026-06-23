class CreateEventApplications < ActiveRecord::Migration[8.0]
  def change
    # A volunteer's application status for an event. The API exposes these as a
    # map (eventId -> status), never by row id, so an integer PK is fine.
    # volunteer_id is mock identity for now (single volunteer v-gm) but kept as a
    # column so multi-volunteer support is a no-op later.
    create_table :event_applications do |t|
      t.string :volunteer_id, null: false
      t.string :event_id, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :event_applications, [:volunteer_id, :event_id], unique: true
  end
end
