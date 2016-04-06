require File.absolute_path('lib/better_chef_rundeck')

# default settings
defaults = {
  cache_dir:  File.join('/', 'tmp', BetterChefRundeck.app_name + '-cache'),
  cache_time: 10,

  # not yet implemented
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

# map defaults keys to environment variables
def to_env_var key
  BetterChefRundeck.env_var_prefix + key.to_s.upcase
end

BetterChefRundeck.configure do
  # environment variables override default values
  # APP_SOME_SETTING env var overrides :some_setting default
  defaults.each { |k, v| App.set k, ENV[to_env_var k] || v }
end

# BetterChefRundeck.configure :production, :development do
#   # TODO: logging
#   enable :logging
# end

# TODO: generate chef config from server url, client name, and client key configs
msg <<-EOM
#{to_env_var chef_server_url}, #{to_env_var chef_client_name}, and #{to_env_var chef_client_key} are
not yet implemented. Chef config can only be generated from #{default_chef_configs.join(', or ')}
right now.
EOM
if [settings.chef_server_url, settings.chef_client_name, settings.chef_client_key].any?
  raise NotImplementedError, msg
end

# if chef_server_url, chef_client_name, or chef_client_key defined, all must be defined
msg <<-EOM
At least one of the following environment variables was set, but not all:
  #{to_env_var chef_server_url}, #{to_env_var chef_client_name}, #{to_env_var chef_client_key}
Either set all of these env vars, or set none of them and use #{to_env_var chef_config}.
EOM
unless [settings.chef_server_url, settings.chef_client_name, settings.chef_client_key].all?
  raise BetterChefRundeck::Error, msg
end

# ensure chef api client can be initialized
msg = <<-EOM
Cannot create query Chef server without necessary config. Do one of the following:
  Create chef config file at #{default_chef_configs.join(', or ')}
  Set chef-config option
  Set chef-server-url, chef-client-name, and chef-client-key options
EOM
raise BetterChefRundeck::Error, msg unless ([options[:chef_config]] + cli_chef_config).any?

run BetterChefRundeck
