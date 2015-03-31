source 'https://rubygems.org'
ruby '2.2.0' #, :engine => "jruby", :engine_version => "1.7.0"

gem 'rails',   '~> 4.2.0'

gem 'pusher'
gem 'crashlog'

gem 'coffee-rails', '~> 4.1.0'
gem 'jquery-rails', '~> 4.0.0'
gem 'sass-rails',   '~> 4.0.0'
gem 'uglifier'

group :deployment do
  gem 'pg', platform: :mri
  gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby

  gem 'puma'
  gem 'rails_12factor'
end

group :development, :test do
  gem 'figaro'
  gem 'rspec-rails'
  gem 'factory_girl_rails'

  platform :mri do
    gem 'sqlite3'
    gem 'byebug'
  end

  platform :jruby do
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end
