class AddIdentifierToDevices < ActiveRecord::Migration[4.2]
  def change
    add_column :devices, :identifier, :string, null: false
    add_index :devices, :identifier, unique: true
  end
end
