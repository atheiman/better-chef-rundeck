require 'sinatra'
require 'chef'

require 'sinatra/reloader' if development?

get '/' do
  'better-chef-rundeck is up and running.'
end

get '/:search_query' do
  "/search/node/#{params['search_query']}"
end

# q = Chef::Search::Query.new
# q.search('node', 'name:pophrundeck*', )

# http://www.rubydoc.info/github/chef/chef/Chef/Search/Query#search-instance_method
# search(type, query = "*:*", *args, &block)
# args now will accept either a Hash of
# search arguments with symbols as the keys (ie :sort, :start, :rows) and a :filter_result
# option.
# search('node', 'name:pophrundeck*', )

# get /search/run_list:base_os
# get /run_list:base_os?ipaddress=ipaddress&default_ssh-authentication=true&override_user=${option.username}
