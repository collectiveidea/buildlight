source 'https://rubygems.org'

gem 'rails', '3.2.9'
gem 'rails-api'

group :deployment do
  gem 'pg'
  gem 'unicorn'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'sqlite3'
  gem 'debugger' unless ENV['CI']
end