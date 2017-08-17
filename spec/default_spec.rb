require 'spec_helper'
require 'chef_zero/server'
require 'ridley'
Ridley::Logging.logger.level = Logger.const_get 'ERROR' # get rid of Celluloid::TaskFiber warnings
require 'json'
require 'yaml'

describe BetterChefRundeck do
  before(:context) do
    # start the chef server
    @server = ChefZero::Server.new(port: 4000, single_org: false, osc_compat: true)
    @server.data_store.create_dir([ 'organizations' ], 'main')
    @server.data_store.create_dir([ 'organizations' ], 'temp')
    @server.start_background

    # create the chef server objects in the chef zero server
    knife_files = ['knife.rb', 'knife_temp.rb']

    knife_files.each do |knife_rb|
      chef_config_file = File.join(File.dirname(__FILE__), 'chef-fixtures', knife_rb)
      ridley = Ridley.from_chef_config(chef_config_file)
      chef_objects_file = File.join(File.dirname(__FILE__), 'chef-fixtures', 'chef-objects.json')
      chef_objects = JSON.parse(File.read(chef_objects_file))
      chef_objects['environments'].each { |env| ridley.environment.create env }
      chef_objects['nodes'].each { |node| ridley.node.create node }
    end
  end

  context 'with nodes loaded into chef server' do
    it '/ should respond ok' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('spec/chef-fixtures/knife.rb')
    end

    context 'when using default organizations' do
      it '/*:* should return all nodes with default filter result' do
        get '/*:*'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(/text\/yaml/)
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

      it 'filter result should be created based on GET params' do
        get '/chef_environment:env_one?ipaddress&fqdn&deep_attr=deep,nested,attribute'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(/text\/yaml/)
        nodes = YAML.load(last_response.body)
        expect(nodes).to eq(
          {"node-1"=>{"ipaddress"=>nil, "fqdn"=>nil, "deep_attr"=>0}}
        )
      end

      it 'appends values when using append_ variable names' do
        get '/chef_environment:env_one?hostname=name&append_hostname=.example.com'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(%r{text\/yaml})
        nodes = YAML.safe_load(last_response.body)
        expect(nodes).to eq(
          'node-1' => {
            'hostname' => 'node-1.example.com'
          }
        )
      end
    end

    context 'when using multi org query' do
      it '/*:* should return all nodes with default filter result' do
        get '/temp/*:*'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(/text\/yaml/)
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

      it 'filter result should be created based on GET params' do
        get '/temp/chef_environment:env_one?ipaddress&fqdn&deep_attr=deep,nested,attribute'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(/text\/yaml/)
        nodes = YAML.load(last_response.body)
        expect(nodes).to eq(
          {"node-1"=>{"ipaddress"=>nil, "fqdn"=>nil, "deep_attr"=>0}}
        )
      end

      it 'appends values when using append_ variable names' do
        get '/temp/chef_environment:env_one?hostname=name&append_hostname=.example.com'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(%r{text\/yaml})
        nodes = YAML.safe_load(last_response.body)
        expect(nodes).to eq(
          'node-1' => {
            'hostname' => 'node-1.example.com'
          }
        )
      end
    end
  end

  after(:context) do
    @server.stop
  end
end
