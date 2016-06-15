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

# ensure chef api client can be initialized
unless File.exists?(File.expand_path(App.settings.chef_config))
  raise App::Error, <<-EOM
Cannot create query Chef server without necessary config. Do one of the following:
  - Create a chef config file at #{(default_chef_configs).join(', or ')}
  - Set env var #{App.to_env_var :chef_config} pointing to a knife.rb or client.rb
EOM
end

run App
