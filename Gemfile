source 'https://rubygems.org'
ruby '2.0.0' #, :engine => "jruby", :engine_version => "1.7.0"

gem 'rails',   '~> 4.0.1'

gem 'pusher'
gem 'crashlog'

gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails', '~> 3.0.0'
gem 'sass-rails',   '~> 4.0.0'
gem 'uglifier',     '>= 1.3.0'

group :deployment do
  gem 'pg', platform: :mri
  gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby

  gem 'puma', '~> 2.7'
  gem 'rails_12factor'
end

group :development, :test do
  gem 'figaro'
  gem 'rspec-rails'
  gem 'factory_girl_rails'

  platform :mri do
    gem 'sqlite3'
    gem 'debugger'
  end

  platform :jruby do
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end
