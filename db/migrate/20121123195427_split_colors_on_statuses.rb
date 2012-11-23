class SplitColorsOnStatuses < ActiveRecord::Migration
  def change
    remove_index :statuses, :color
    remove_index :statuses, [:project_id, :color]
    remove_index :statuses, [:project_id, :color, :created_at]

    add_column :statuses, :red, :boolean
    add_column :statuses, :yellow, :boolean
    remove_column :statuses, :color

    add_index :statuses, :red
    add_index :statuses, :yellow
  end
end
