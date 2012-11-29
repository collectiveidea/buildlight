source 'https://rubygems.org'
ruby '1.9.3'

gem 'rails', github: 'rails/rails'
gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders'
gem 'journey', github: 'rails/journey'

gem 'crashlog'

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