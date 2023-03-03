class TriggerWebhook
  def self.call(device)
    Faraday.post(device.webhook_url, {colors: device.colors}.to_json, {"Content-Type": "application/json"})
  end
end
