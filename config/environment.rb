require 'bundler'
require 'active_record'
require 'yaml'
Bundler.require

db_config = YAML.load_file('db/config.yml')[ENV['ENVIRONMENT'] || 'development']

ActiveRecord::Base.establish_connection(adapter: db_config['adapter'], database: db_config['database'])
ActiveRecord::Base.logger = nil
Dir["lib/*.rb"].each {|file| require_relative "../#{file}" }
