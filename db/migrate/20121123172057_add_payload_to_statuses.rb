class AddPayloadToStatuses < ActiveRecord::Migration[4.2]
  def change
    add_column :statuses, :payload, :text
  end
end
