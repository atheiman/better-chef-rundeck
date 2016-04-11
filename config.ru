require 'rubygems'
require 'bundler'

Bundler.require

require File.absolute_path('lib/better_chef_rundeck')

# alias the sinatra app class
App = BetterChefRundeck

# default settings for the app
defaults = {
  cache_dir:  File.join('/', 'tmp', App.app_name + '-cache'),
  cache_time: 30,
  chef_config: nil,

  # TODO: not yet implemented
  chef_server_url: nil,
  chef_client_name: nil,
  chef_client_key: nil,
}
# defaulting the chef config file is more complicated
default_chef_configs = ['~/.chef/knife.rb', '/etc/chef/client.rb']
default_chef_configs.each do |c|
  if File.exists?(File.expand_path(c))
    defaults[:chef_config] = c
    break
  end
end

# configure the app settings from defaults hash (defaults and env vars)
App.configure do
  # environment variables override default values
  # APP_SOME_SETTING env var overrides :some_setting default
  defaults.each { |k, v| App.set k, ENV[App.to_env_var k] || v }
  # settings are stored as strings. reference cache time with settings.cache_time.to_f
end

# App.configure :production, :development do
#   # TODO: logging
#   enable :logging
# end

# ensure the necessary config / env vars exist to run the app
chef_vars = [:chef_server_url, :chef_client_name, :chef_client_key].map {|e| App.to_env_var e}
chef_settings = [App.settings.chef_server_url, App.settings.chef_client_name,
                 App.settings.chef_client_key]
chef_config_env_var = App.to_env_var :chef_config
# TODO: generate chef config from server url, client name, and client key configs
if chef_settings.any?
  raise NotImplementedError, <<-EOM
#{chef_vars.join(', ')} are not yet implemented. Chef config currently can only be generated from
#{default_chef_configs.join(', or ')}.
EOM
end

# if chef_server_url, chef_client_name, or chef_client_key defined, all must be defined
if chef_settings.any? && !chef_settings.all?
  raise App::Error, <<-EOM
At least one of the following environment variables was set, but not all:
  #{chef_vars.join(', ')}
Either set all of these env vars, or none of them and set #{chef_config_env_var} instead.
EOM
end

# ensure chef api client can be initialized
unless File.exists?(File.expand_path(App.settings.chef_config)) || chef_settings.all?
  raise App::Error, <<-EOM
Cannot create query Chef server without necessary config. Do one of the following:
  - Create a chef config file at #{(default_chef_configs).join(', or ')}
  - Set env var #{chef_config_env_var} pointing to a knife.rb or client.rb
  - Set env vars #{chef_vars.join(', ')}
EOM
end

run App
