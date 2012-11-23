# unicorn_rails -c /data/github/current/config/unicorn.rb -E production -D

rails_env = ENV['RAILS_ENV'] || 'production'

# 3 workers and 1 master
worker_processes 3

# Load rails+github.git into the master before forking workers
# for super-fast worker spawn times
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 30

after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
end
