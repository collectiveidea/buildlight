class AddPayloadToStatuses < ActiveRecord::Migration
  def change
    add_column :statuses, :payload, :text
  end
end
