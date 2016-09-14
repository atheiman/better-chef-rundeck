require 'spec_helper'
require 'chef_zero/server'
require 'ridley'
Ridley::Logging.logger.level = Logger.const_get 'ERROR' # get rid of Celluloid::TaskFiber warnings
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
      expect(nodes).to eq(
        {"bcr-node"=>
          {"environment"=>"bcr_env",
           "fqdn"=>nil,
           "ip"=>nil,
           "run_list"=>["recipe[global_cookbook]", "role[bcr_role]"],
           "roles"=>nil,
           "platform"=>nil,
           "tags"=>nil},
         "node-1"=>
          {"environment"=>"env_one",
           "fqdn"=>nil,
           "ip"=>nil,
           "run_list"=>["recipe[global_cookbook]", "role[node_one_role]"],
           "roles"=>nil,
           "platform"=>nil,
           "tags"=>nil},
         "node-2"=>
          {"environment"=>"env_two",
           "fqdn"=>nil,
           "ip"=>nil,
           "run_list"=>["recipe[global_cookbook]", "role[node_two_role]"],
           "roles"=>nil,
           "platform"=>nil,
           "tags"=>nil}}
      )
    end
  end

  after(:context) do
    @server.stop
  end
end
