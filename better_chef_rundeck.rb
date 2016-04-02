require 'sinatra'
require 'chef'

require 'sinatra/reloader' if development?

get '/' do
  'hello world'
end
