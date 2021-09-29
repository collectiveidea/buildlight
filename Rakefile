#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path("../config/application", __FILE__)

Buildlight::Application.load_tasks

task default: [:standard, "css:build", :spec]

task("assets:precompile").clear
namespace :assets do
  task precompile: ["yarn:install", "css:build"]
end
