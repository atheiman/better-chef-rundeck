require 'spec_helper'
require 'chef_zero/server'
require 'ridley'
# get rid of Celluloid::TaskFiber warnings
Ridley::Logging.logger.level = Logger.const_get 'ERROR'
require 'json'
require 'yaml'

describe BetterChefRundeck do
  before(:context) do
    # start the chef server
    @server = ChefZero::Server.new(port: 4000)
    @server.start_background

    # create the chef server objects in the chef zero server
    chef_config_file = File.join(File.dirname(__FILE__), 'chef-fixtures', 'knife.rb')
    ridley = Ridley.from_chef_config(chef_config_file)
    chef_objects_file = File.join(File.dirname(__FILE__), 'chef-fixtures', 'chef-objects.json')
    chef_objects = JSON.parse(File.read(chef_objects_file))
    chef_objects['environments'].each { |env| ridley.environment.create env }
    chef_objects['nodes'].each { |node| ridley.node.create node }
    puts ridley.node.all
  end

  context 'with nodes loaded into chef server' do
    it '/ should respond ok' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('spec/chef-fixtures/knife.rb')
    end

    it '/*:* should return all nodes with default filter result' do
      get '/*:*'
      expect(last_response).to be_ok
      nodes = YAML.load(last_response.body)
      expect(nodes.keys).to eq(['bcr-node', 'node-1', 'node-2'])
    end
  end

  after(:context) do
    @server.stop
  end
end
