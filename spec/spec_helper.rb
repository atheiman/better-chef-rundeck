# require_relative '../lib/better_chef_rundeck'
require 'rack/test'
require 'rspec'
require_relative '../lib/better_chef_rundeck'

ENV['RACK_ENV'] = 'test'

# configure the app settings (this is done similarly in config.ru)
BetterChefRundeck.configure do
  {
    cache_dir:  File.join(File.dirname(__FILE__), '..', 'cache'),
    cache_time: 30,
    chef_config: File.join(File.dirname(__FILE__), 'chef-fixtures', 'knife.rb'),
  }.each { |k, v| BetterChefRundeck.set k, v }
end

module RSpecMixin
  include Rack::Test::Methods
  def app() BetterChefRundeck end
end

RSpec.configure do |config|
  config.include RSpecMixin
end
