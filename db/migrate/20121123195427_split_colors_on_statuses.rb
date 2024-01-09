class SplitColorsOnStatuses < ActiveRecord::Migration[4.2]
  def change
    change_table :statuses, bulk: true do |t|
      t.remove_index :color
      t.remove_index [:project_id, :color]
      t.remove_index [:project_id, :color, :created_at]

      t.boolean :red
      t.boolean :yellow
      t.remove :color, type: :string

      t.index :red
      t.index :yellow
    end
  end
end
