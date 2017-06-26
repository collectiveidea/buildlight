class CreateStatuses < ActiveRecord::Migration[4.2]
  def change
    create_table :statuses do |t|
      t.string :project_id
      t.string :project_name
      t.string :status

      t.timestamps
    end

    add_index :statuses, :project_id
    add_index :statuses, :project_name
    add_index :statuses, :status
    add_index :statuses, [:project_id, :status]
    add_index :statuses, [:project_id, :status, :created_at]
  end
end
