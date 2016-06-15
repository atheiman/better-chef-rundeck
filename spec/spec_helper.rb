# require_relative '../lib/better_chef_rundeck'
require 'rack/test'
require 'rspec'
require 'chef_zero/server'
require 'ridley'
require 'json'

# get rid of Celluloid::TaskFiber warnings
Ridley::Logging.logger.level = Logger.const_get 'ERROR'

ENV['RACK_ENV'] = 'test'

require_relative '../lib/better_chef_rundeck'

# configure the app settings (this is done similarly in config.ru)
BetterChefRundeck.configure do
  {
    cache_dir:  File.join(__FILE__, '..', 'cache'),
    cache_time: 30,
    chef_config: File.join(__FILE__, 'chef-fixtures', 'knife.rb'),
  }.each do |k, v|
    BetterChefRundeck.set k, v
  end
end

# start the chef server
server = ChefZero::Server.new(port: 4000)
server.start_background

# create the chef server objects in the chef zero server
chef_config_file = File.join(File.dirname(__FILE__), 'chef-fixtures', 'knife.rb')
ridley = Ridley.from_chef_config(chef_config_file)
chef_objects_file = File.join(File.dirname(__FILE__), 'chef-fixtures', 'chef-objects.json')
chef_objects = JSON.parse(File.read(chef_objects_file))
chef_objects['environments'].each { |env| ridley.environment.create env }
chef_objects['nodes'].each { |node| ridley.node.create node }


module RSpecMixin
  include Rack::Test::Methods
  def app() BetterChefRundeck end
end

RSpec.configure do |config|
  config.include RSpecMixin
end
