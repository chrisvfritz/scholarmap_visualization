require 'sinatra/base'
require 'slim'

class ScholarMapApiMock < Sinatra::Base

  ENDPOINTS = %w(people references)

  get '/docs' do
    slim :index, locals: { endpoints: ENDPOINTS }
  end

  ENDPOINTS.each do |endpoint|

    get "/#{endpoint}/graphs/force-directed.json" do
      json_response 200, "#{endpoint}.json"
    end

    get "/docs/#{endpoint}" do
      slim "endpoints/#{endpoint}".to_sym
    end

  end

private

  def json_response(response_code, file_name)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + '/fixtures/scholar_map_api_mock/' + file_name, 'rb').read
  end
end