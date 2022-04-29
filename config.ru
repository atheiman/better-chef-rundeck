require 'rubygems'
require 'bundler'

Bundler.require

require File.absolute_path('lib/better_chef_rundeck')

# alias the sinatra app class
App = BetterChefRundeck

# default settings for the app
defaults = {
  chef_config: nil
}
# defaulting the chef config file is more complicated
default_chef_configs = ['/home/app/.chef/knife.rb', '~/.chef/knife.rb', '/etc/chef/client.rb']
default_chef_configs.each do |c|
  if File.exist?(File.expand_path(c))
    defaults[:chef_config] = c
    break
  end
end

# configure the app settings from defaults hash (defaults and env vars)
App.configure do
  # environment variables override default values
  # APP_SOME_SETTING env var overrides :some_setting default
  defaults.each { |k, v| App.set k, ENV[App.to_env_var k] || v }
  # settings are stored as strings
end

# App.configure :production, :development do
#   # TODO: logging
#   enable :logging
# end

# ensure chef api client can be initialized
unless File.exist?(File.expand_path(App.settings.chef_config))
  raise App::Error, <<-EOM
Cannot create query Chef server without necessary config. Do one of the following:
  - Create a chef config file at #{(default_chef_configs).join(', or ')}
  - Set env var #{App.to_env_var :chef_config} pointing to a knife.rb or client.rb
EOM
end

Chef::Config.from_file(File.expand_path(App.settings.chef_config))

run App
