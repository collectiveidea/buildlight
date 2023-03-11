class AddWorkflowToStatues < ActiveRecord::Migration[7.0]
  def change
    add_column :statuses, :workflow, :string
  end
end
