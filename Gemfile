source :rubygems
ruby '1.9.3', :engine => "jruby", :engine_version => "1.7.0"

gem 'rails',   github: 'rails/rails'
gem 'journey', github: 'rails/journey'
gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders'

gem 'crashlog'

group :deployment do
  platform :mri do
    gem 'pg'
  end

  platform :jruby do
    gem 'jdbc-postgres'
    gem 'activerecord-jdbc-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
  end

  gem 'puma', '~> 2.0.0.b3'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'

  platform :mri do
    gem 'sqlite3'
    gem 'debugger' unless ENV['CI']
  end
end
