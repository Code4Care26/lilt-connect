class AddScheduleToEvents < ActiveRecord::Migration[8.0]
  # Real schedule fields, alongside the human date_label/time_label strings (which
  # stay for display). starts_at + duration_minutes make hours and time-window
  # aggregations computable ("ore donate in un periodo") — strings can't be summed
  # or ordered. Nullable: events created via the API don't set them yet.
  def change
    add_column :events, :starts_at, :datetime
    add_column :events, :duration_minutes, :integer
  end
end
