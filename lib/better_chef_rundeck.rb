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
    content = <<-EOS.gsub /^\s+/, ""
    #{BetterChefRundeck.app_name} is up and running!
    cache_dir: #{settings.cache_dir}
    cache_time: #{settings.cache_time}
    chef_config: #{settings.chef_config}
    EOS
  end

  get /\/(.+:.+)/ do |q|
    # mkdir cache dir if needed
    Dir.mkdir(settings.cache_dir) unless File.directory?(settings.cache_dir)

    # delete old cache files
    Dir.glob(File.join(File.expand_path(settings.cache_dir), '*')).each do |f|
      File.delete f if (Time.now - File.mtime(f)) > settings.cache_time.to_f
    end

    # name cache files <query>.yml
    cache_file = File.join(settings.cache_dir,
                           URI.escape(q + request.query_string).gsub(/\//, '__SLASH__')) + '.yml'

    # send the cache file if it exists
    send_file cache_file if File.exists? cache_file

    # search results not cached, query the chef server
    # TODO: generate chef config from cli options if provided
    Chef::Config.from_file(File.expand_path(settings.chef_config))

    # set defaults and overrides from GET params
    params_clone = params.clone
    params_clone.delete 'splat'
    params_clone.delete 'captures'
    defaults, overrides = {}, {}

    params_clone.each do |k, v|
      if k.match(/^default_.+/)
        defaults[k.sub(/^default_/, '')] = v
        params_clone.delete k
      elsif k.match(/^override_.+/)
        overrides[k.sub(/^override_/, '')] = v
        params_clone.delete k
      end
    end

    # always default name to name, it can still be overriden by specifying ?name=some,attr,path
    filter_result = {name: ['name']}
    # the only keys left in params_clone are for filter_result
    if params_clone.empty?
      # if no GET params were given for filter_result to be generated, use the default
      default_filter_result = {
        environment: ['chef_environment'],
        fqdn:        ['fqdn'],
        ip:          ['ipaddress'],
        run_list:    ['run_list'],
        roles:       ['roles'],
        platform:    ['platform'],
        tags:        ['tags'],
      }
      filter_result = filter_result.merge default_filter_result
    else
      # if some GET params were given for filter_result, use them instead
      params_clone.each do |k, v|
        # TODO: logging
        # logger.warn "attribute #{k} defaulted to nil" if v.nil?
        filter_result[k] = v.split(',')
      end
    end

    # query the chef server
    chef_nodes = Chef::Search::Query.new.search(:node, q, filter_result: filter_result)[0]

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
      node.merge!(defaults) { |key, node_val, default_val| default_val if node_val.nil? }
      # merge in override attributes (overwrite all node attributes)
      node.merge!(overrides)
      formatted_nodes[node.delete('name')] = node
    end

    # create the cache file
    File.write(cache_file, formatted_nodes.to_yaml)

    # send the cache file
    send_file cache_file
  end
end
