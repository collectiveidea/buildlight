source "https://rubygems.org"
ruby "3.0.2"

gem "rails", "~> 7.0.0.alpha2"

gem "pg"

gem "bootsnap"
gem "honeybadger"
gem "particlerb"
gem "puma"

gem "jsbundling-rails"
# gem "coffee-rails"
gem "cssbundling-rails"

group :production do
  gem "lograge"
end

group :development, :test do
  gem "byebug"
  gem "factory_bot_rails"
  gem "figaro"
  gem "rspec-rails"
  gem "standard"
end

group :test do
  gem "rspec-ontap", require: false
end
