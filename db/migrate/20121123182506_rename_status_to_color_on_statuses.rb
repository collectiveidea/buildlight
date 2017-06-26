class RenameStatusToColorOnStatuses < ActiveRecord::Migration[4.2]
  def change
    remove_index :statuses, :status
    remove_index :statuses, [:project_id, :status]
    remove_index :statuses, [:project_id, :status, :created_at]

    rename_column :statuses, :status, :color

    add_index :statuses, :color
    add_index :statuses, [:project_id, :color]
    add_index :statuses, [:project_id, :color, :created_at]
  end
end
