require 'spec_helper'
require 'chef_zero/server'
require 'json'
require 'yaml'

describe BetterChefRundeck do
  before(:context) do
    chef_fixtures_location = File.join(File.dirname(__FILE__), 'chef-fixtures')

    # starting chefzero server
    Chef::Config.chef_server_url = 'http://127.0.0.1:4000/organizations/main'
    Chef::Config.node_name = 'bcr-node'
    Chef::Config.client_key = File.join(chef_fixtures_location, 'bcr-node.pem')

    @server = ChefZero::Server.new(port: 4000, single_org: false, osc_compat: true)

    @server.data_store.create_dir(['organizations'], 'main')
    @server.data_store.create_dir(['organizations'], 'temp')

    # create the chef server objects in the chef zero server
    @server.load_data(YAML.load_file(File.join(chef_fixtures_location, 'chef-objects.yml')), 'main')
    @server.load_data(YAML.load_file(File.join(chef_fixtures_location, 'chef-objects_temp.yml')), 'temp')

    @server.start_background
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
             "tags"=>["bcr-tag", "global-tag"]},
           "node-1"=>
            {"environment"=>"env_one",
             "fqdn"=>nil,
             "ip"=>nil,
             "run_list"=>["recipe[global_cookbook]", "role[node_one_role]"],
             "roles"=>nil,
             "platform"=>nil,
             "tags"=>["node-1-tag", "global-tag"]},
           "node-2"=>
            {"environment"=>"env_two",
             "fqdn"=>nil,
             "ip"=>nil,
             "run_list"=>["recipe[global_cookbook]", "role[node_two_role]"],
             "roles"=>nil,
             "platform"=>nil,
             "tags"=>["node-2-tag", "global-tag"]}}
        )
      end

      it '/main/*:* should return the same result as /*:*' do
        get '/main/*:*'
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
             "tags"=>["bcr-tag", "global-tag"]},
           "node-1"=>
            {"environment"=>"env_one",
             "fqdn"=>nil,
             "ip"=>nil,
             "run_list"=>["recipe[global_cookbook]", "role[node_one_role]"],
             "roles"=>nil,
             "platform"=>nil,
             "tags"=>["node-1-tag", "global-tag"]},
           "node-2"=>
            {"environment"=>"env_two",
             "fqdn"=>nil,
             "ip"=>nil,
             "run_list"=>["recipe[global_cookbook]", "role[node_two_role]"],
             "roles"=>nil,
             "platform"=>nil,
             "tags"=>["node-2-tag", "global-tag"]}}
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
          {
            'bcr-node2' => {
              'environment' => 'bcr_env2',
              'fqdn' => nil,
              'ip' => nil,
              'run_list' => ['recipe[global_cookbook]', 'role[bcr_role2]'],
              'roles' => nil,
              'platform' => nil,
              'tags' => ['bcr-tag2', 'global-tag']
            },
            'temp-node'=> {
              'environment' => 'temp_env',
              'fqdn' => nil,
              'ip' => nil,
              'run_list' => ['recipe[global_cookbook]', 'role[temp_role]'],
              'roles' => nil,
              'platform' => nil,
              'tags' => ['temp-tag', 'global-tag']
            },
            "temp-node2" => {
              'environment' => 'temp_env2',
              'fqdn' => nil,
              'ip' => nil,
              'run_list' => ['recipe[global_cookbook]', 'role[temp_role2]'],
              'roles' => nil,
              'platform' => nil,
              'tags' => ['temp-tag2', 'global-tag']
            }
          }
        )
      end

      it 'filter result should be created based on GET params' do
        get '/temp/chef_environment:temp_env?ipaddress&fqdn&deep_attr=deep,nested,attribute'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(/text\/yaml/)
        nodes = YAML.load(last_response.body)
        expect(nodes).to eq(
          {
            'temp-node' => {
              'ipaddress' => nil,
              'fqdn' => nil,
              'deep_attr' => 0
            }
          }
        )
      end

      it 'appends values when using append_ variable names' do
        get '/temp/chef_environment:temp_env?hostname=name&append_hostname=.example.com'
        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to match(%r{text\/yaml})
        nodes = YAML.safe_load(last_response.body)
        expect(nodes).to eq(
          'temp-node' => { 'hostname' => 'temp-node.example.com' }
        )
      end
    end
  end

  after(:context) do
    @server.stop
  end
end
