class DropApplicants < ActiveRecord::Migration[8.0]
  # The staff "manage applications" screen now reads real volunteer applications
  # (event_applications) instead of a separate, seed-only applicant roster.
  def up
    drop_table :applicants
  end

  def down
    create_table :applicants, id: :string, force: :cascade do |t|
      t.string :name
      t.string :initials
      t.string :pref
      t.string :color
      t.string :status, default: "pending"
      t.string :event_id, null: false
      t.timestamps
      t.index :event_id, name: "index_applicants_on_event_id"
    end
    add_foreign_key :applicants, :events
  end
end
