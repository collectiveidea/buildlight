class MakeIdentifierNullableOnDevices < ActiveRecord::Migration[7.0]
  def change
    change_column_null :devices, :identifier, true
  end
end
