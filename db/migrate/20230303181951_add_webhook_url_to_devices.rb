class AddWebhookUrlToDevices < ActiveRecord::Migration[7.0]
  def change
    add_column :devices, :webhook_url, :string
  end
end
