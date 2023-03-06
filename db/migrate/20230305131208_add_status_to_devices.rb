class AddStatusToDevices < ActiveRecord::Migration[7.0]
  def change
    add_column :devices, :status, :string
    add_column :devices, :status_changed_at, :datetime
  end
end
