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
    defaults, overrides = {}, {}
    params_hsh.each do |k, v|
      if k.match(/^default_.+/)
        defaults[k.sub(/^default_/, '')] = v
        params_hsh.delete k
      elsif k.match(/^override_.+/)
        overrides[k.sub(/^override_/, '')] = v
        params_hsh.delete k
      end
    end
    return params_hsh, defaults, overrides
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
        # TODO: logging
        # logger.warn "attribute #{k} defaulted to nil" if v.nil?
        filter_result[k] = v.split(',')
      end
    end
    filter_result
  end

  get(/\/(.+:.+)/) do |query|
    content_type 'text/yaml'

    # clean sinatra extras from params hash
    params_clone = clean_params params

    # set defaults and overrides from GET params
    params_clone, defaults, overrides = get_defaults_overrides params_clone

    # build a filter result for a chef partial search from the remaining GET params
    filter_result = get_filter_result params_clone

    # query the chef server
    chef_nodes = Chef::Search::Query.new.search(:node, query, filter_result: filter_result)[0]

    # format nodes for yaml: {<name>: {<attr>: <value>, <attr>: <value>}}
    formatted_nodes = {}
    chef_nodes.each do |node|
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
      formatted_nodes[node.delete('name')] = node
    end

    # send the nodes
    formatted_nodes.to_yaml
  end
end
