class AddSlugToDevices < ActiveRecord::Migration[7.0]
  def change
    enable_extension :citext
    add_column :devices, :slug, :citext, null: true
    add_index :devices, :slug, unique: true
  end
end
