source "https://rubygems.org"
ruby "3.3.0"

gem "rails", "~> 7.1.2"

gem "pg"

gem "bootsnap"
gem "honeybadger"
gem "particlerb"
gem "puma"

gem "importmap-rails"
gem "cssbundling-rails"
gem "propshaft"

# This gem is pulled in via ActionCable, so remove when the PR is merged.
# https://github.com/faye/websocket-driver-ruby/pull/85
gem "websocket-driver", github: "danielmorrison/websocket-driver-ruby", branch: "support-frozen-by-default"

group :production do
  gem "lograge"
end

group :development, :test do
  gem "debug"
  gem "factory_bot_rails"
  gem "figaro"
  gem "rspec-rails"
  gem "standard"
  gem "standard-performance"
  gem "standard-rails"
end

group :test do
  gem "rspec-ontap", require: false
end
