module JSONHelpers
  ENV = {'CONTENT_TYPE' => 'application/json'}

  def json_fixture(filename)
    File.read(Rails.root.join('spec', 'fixtures', filename))
  end

  def post_json(path, json)
    post(path, json, ENV)
  end

  def app
    Capybara.app
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JSONHelpers
end
