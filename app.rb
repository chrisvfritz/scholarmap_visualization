require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'coffee-script'

class ScholarMapViz < Sinatra::Base

  API_BASE = '/api/v1'

  get '/coffee/*.js' do
    filename = params[:splat].first
    coffee "../public/coffee/#{filename}".to_sym
  end

  get '/' do
    erb :index
  end

end
