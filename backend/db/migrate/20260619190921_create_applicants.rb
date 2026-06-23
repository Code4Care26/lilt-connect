class CreateApplicants < ActiveRecord::Migration[8.0]
  def change
    # String primary key (p1..p9 in the seed) to mirror the mock ids.
    create_table :applicants, id: :string do |t|
      t.string :name
      t.string :initials
      t.string :pref
      t.string :color
      t.string :status, default: "pending"
      t.string :event_id, null: false

      t.timestamps
    end

    add_index :applicants, :event_id
    add_foreign_key :applicants, :events
  end
end
