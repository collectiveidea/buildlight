class AddStatusToDevices < ActiveRecord::Migration[7.0]
  def change
    change_table :devices, bulk: true do |t|
      t.string :status
      t.datetime :status_changed_at
    end
  end
end
