source 'https://rubygems.org'
ruby '2.0.0' #, :engine => "jruby", :engine_version => "1.7.0"

gem 'rails',   '4.0.0.rc2'

gem 'pusher'
gem 'crashlog'

gem 'sass-rails', '~> 4.0.0.rc1'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem "jquery-rails", "~> 2.2"

group :deployment do
  gem 'pg', platform: :mri
  gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby

  gem 'puma', '~> 2.0.0.b3'
end

group :development, :test do
  gem 'figaro'
  gem 'rspec-rails'
  gem 'factory_girl_rails'

  platform :mri do
    gem 'sqlite3'
    gem 'debugger' unless ENV['CI']
  end

  platform :jruby do
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end
