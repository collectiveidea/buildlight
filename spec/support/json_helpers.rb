module JSONHelpers
  ENV = {"CONTENT_TYPE" => "application/json"}.freeze

  def json_fixture(filename)
    File.read(Rails.root.join("spec", "fixtures", filename))
  end
end

RSpec.configure do |config|
  config.include JSONHelpers
end
