class AddNameToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :name, :string, null: false
    add_index :devices, :name
  end
end
