require 'sinatra/base'
require 'uri'
require 'yaml'
require 'chef'

class BetterChefRundeck < Sinatra::Base
  class Error < StandardError
  end

  if development?
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  def self.app_name
    'better-chef-rundeck'
  end
  def self.env_var_prefix
    'BCR_'
  end
  def self.to_env_var key
    self.env_var_prefix + key.to_s.upcase
  end

  get '/' do
    content_type 'text/plain'
    <<-EOS.gsub(/^\s+/, "")
    #{BetterChefRundeck.app_name} is up and running!
    chef_config: #{settings.chef_config}
    EOS
  end

  # remove some extra keys Rack / Sinatra add to the params hash
  def clean_params params_hsh
    clone = params_hsh.clone
    clone.delete 'splat'
    clone.delete 'captures'
    clone
  end

  # parse params hash for default_ and override_ keys
  def get_defaults_overrides params_hsh
    defaults, overrides, appends = {}, {}, {}
    params_hsh.each do |k, v|
      if k.match(/^default_.+/)
        defaults[k.sub(/^default_/, '')] = v
        params_hsh.delete k
      elsif k.match(/^override_.+/)
        overrides[k.sub(/^override_/, '')] = v
        params_hsh.delete k
      elsif k.match(/^append_.+/)
        appends[k.sub(/^append_/, '')] = v
        params_hsh.delete k
      end
    end
    return params_hsh, defaults, overrides, appends
  end

  # build a filter result for a chef partial search from the params hash
  def get_filter_result params_hsh
    default_filter_result = {
      environment: ['chef_environment'],
      fqdn:        ['fqdn'],
      ip:          ['ipaddress'],
      run_list:    ['run_list'],
      roles:       ['roles'],
      platform:    ['platform'],
      tags:        ['tags'],
    }
    # always default name to name, it can still be overriden by specifying ?name=some,attr,path
    filter_result = {name: ['name']}
    # the only keys left in params_hsh should be for filter_result
    if params_hsh.empty?
      # if no GET params were given for filter_result to be generated, use the default
      filter_result = filter_result.merge default_filter_result
    else
      # if some GET params were given for filter_result, use them instead
      params_hsh.each do |k, v|
        if v.nil?
          # attribute path not specified, assume key is attribute path
          filter_result[k] = [k]
        else
          # attribute path specified
          filter_result[k] = v.split(',')
        end
      end
    end
    filter_result
  end

  def filter_organization(query)
    return nil, query unless query =~ %r{\w+/.+:.+}

    organization, search_query = query.split('/')
    chef_server_url = Chef::Config[:chef_server_url]

    splitted = chef_server_url.split('/')
    splitted.pop
    splitted.push(organization)
    chef_server_url = splitted.join('/')

    return chef_server_url, search_query
  end

  get(/\/(.+:.+)/) do |query|
    content_type 'text/yaml'

    # clean sinatra extras from params hash
    params_clone = clean_params params

    # set defaults and overrides from GET params
    params_clone, defaults, overrides, appends = get_defaults_overrides params_clone

    # build a filter result for a chef partial search from the remaining GET params
    filter_result = get_filter_result params_clone

    # format nodes for yaml: {<name>: {<attr>: <value>, <attr>: <value>}}
    formatted_nodes = {}

    # processing query with organization(<organizatio>/<query>)
    chef_server_url, search_query = filter_organization(query)

    # query the chef server
    Chef::Search::Query.new(chef_server_url).search(:node, search_query, filter_result: filter_result) do |node|
      # 400 error if name attribute is nil
      if node['name'].nil?
        halt 400, "Error: node(s) missing name attribute. You've overriden the `name` \
attribute to the attribute path `#{params['name']}` in your GET parameters \
`#{request.query_string}`"
      end

      # merge in default attributes (overwrite nil node attributes)
      node.merge!(defaults) { |_key, node_val, default_val| default_val if node_val.nil? }
      # merge in override attributes (overwrite all node attributes)
      node.merge!(overrides)
      node.merge!(appends) { |_key, node_val, append_val| "#{node_val}#{append_val}" unless node_val.nil? }

      formatted_nodes[node.delete('name')] = node
    end

    # send the nodes
    formatted_nodes.to_yaml
  end
end
