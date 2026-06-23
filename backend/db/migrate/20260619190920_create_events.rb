class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    # String primary key: events keep the canonical ids the frontend uses in
    # URLs and state (e1..e5, and slugs like ev-tour-6 for created events).
    create_table :events, id: :string do |t|
      t.string :title
      t.string :kind
      t.string :subtitle
      t.string :date_label
      t.string :time_label
      t.string :place
      t.string :address
      t.string :poster
      t.string :icon
      t.string :badge
      t.string :badge_bg
      t.string :badge_fg
      t.text :description
      # roles is a string[], slots is { approved, available } — JSON columns
      # so the API echoes the same array/object the mock returns.
      t.json :roles, default: []
      t.json :slots, default: {}
      t.integer :applications_count, default: 0
      t.integer :waitlist_count, default: 0
      t.string :status, default: "draft"
      t.string :reason

      t.timestamps
    end
  end
end
