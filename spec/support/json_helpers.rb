module JSONHelpers
  ENV = {"CONTENT_TYPE" => "application/json"}.freeze

  def json_fixture(filename)
    Rails.root.join("spec", "fixtures", filename).read
  end
end

RSpec.configure do |config|
  config.include JSONHelpers
end
