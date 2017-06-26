class CreateDevices < ActiveRecord::Migration[4.2]
  def change
    enable_extension "uuid-ossp"

    create_table :devices, id: :uuid do |t|
      t.string :usernames, array: true, default: [], null: false
      t.string :projects, array: true, default: [], null: false

      t.timestamps null: false
    end
  end
end
