class AddContactsToEventApplications < ActiveRecord::Migration[8.0]
  # Mock contact details for the staff "manage applications" roster, so staff can
  # reach a volunteer directly (call / WhatsApp / email). There is no real users
  # table yet (Readme §10): values are generated deterministically from the
  # volunteer name on create (see EventApplication#assign_mock_contacts).
  def change
    add_column :event_applications, :phone, :string
    add_column :event_applications, :email, :string
  end
end
