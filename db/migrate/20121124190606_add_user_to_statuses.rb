class AddUserToStatuses < ActiveRecord::Migration[4.2]
  def change
    add_column :statuses, :username, :string
    add_index :statuses, :username
    add_index :statuses, [:username, :project_name]
    add_index :statuses, [:username, :red]
    add_index :statuses, [:username, :yellow]
  end
end
