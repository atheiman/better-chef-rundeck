require 'uri'
require 'yaml'
require 'chef'
require 'sinatra'

class BetterChefRundeck < Sinatra::Base
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  get '/' do
    "#{File.basename($0)} is up and running\ncache_dir: #{settings.cache_dir}"
  end

  get '/favicon.ico' do
    status 404
  end

  get /\/(.+:.+)/ do |q|
    # mkdir cache dir if needed
    Dir.mkdir(settings.cache_dir) unless File.directory?(settings.cache_dir)

    # delete old cache files
    Dir.glob(File.join(settings.cache_dir, '*')).each do |f|
      File.delete f if (Time.now - File.mtime(f)) > settings.cache_time
    end

    # name cache files <query>.yml
    cache_file = File.join(settings.cache_dir, URI.escape(q + request.query_string)) + '.yml'

    # send the cache file if it exists
    send_file cache_file if File.exists? cache_file

    # search results not cached, query the chef server
    Chef::Config.from_file(File.expand_path(settings.chef_config))

    # set defaults and overrides from GET params
    cloned = params.clone
    cloned.delete 'splat'
    cloned.delete 'captures'
    defaults, overrides = {}, {}
    filter_result = {
      name:        ['name'],
      environment: ['chef_environment'],
      fqdn:        ['fqdn'],
      ip:          ['ipaddress'],
      run_list:    ['run_list'],
      roles:       ['roles'],
      platform:    ['platform'],
      tags:        ['tags'],
    }
    cloned.each do |k, v|
      # default attributes
      if k.start_with? 'default_'
        defaults[k.sub(/^default_/, '')] = v
      # override attributes
      elsif k.start_with? 'override_'
        overrides[k.sub(/^override_/, '')] = v
      # filter_result
      else
        filter_result[k] = v.split(',')
      end
    end

    puts "defaults: #{defaults}"
    puts "overrides: #{overrides}"
    puts "filter_result: #{filter_result}"

    chef_nodes = Chef::Search::Query.new.search(:node, q, filter_result: filter_result)[0]

    # TODO: add defaults and overrides to each chef node

    formatted_nodes = {}
    chef_nodes.each do |n|
      formatted_nodes[n.delete('name')] = n
    end
    File.write(cache_file, formatted_nodes.to_yaml)
    send_file cache_file
  end
end

# get /run_list:base_os?ipaddress=ipaddress&default_ssh-authentication=true&override_username=${option.username}
