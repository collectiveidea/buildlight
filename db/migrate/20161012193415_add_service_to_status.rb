class AddServiceToStatus < ActiveRecord::Migration[5.0]
  class Status < ApplicationRecord
  end

  def up
    add_column :statuses, :service, :string
    Status.update_all(service: "travis")
    change_column :statuses, :service, :string, null: false
  end

  def down
    remove_column :statuses, :service
  end
end
