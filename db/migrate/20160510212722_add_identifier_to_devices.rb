class AddIdentifierToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :identifier, :string, null: false
    add_index :devices, :identifier, unique: true
  end
end
