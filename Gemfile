source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.0.1"

gem "pg"

gem "bootsnap"
gem "dockerfile-rails"
gem "honeybadger"
gem "ostruct" # Required by particlerb
gem "particlerb"
gem "puma"

gem "importmap-rails"
gem "cssbundling-rails"
gem "propshaft"

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
