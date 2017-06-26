class AddNameToDevices < ActiveRecord::Migration[4.2]
  def change
    add_column :devices, :name, :string, null: false
    add_index :devices, :name
  end
end
