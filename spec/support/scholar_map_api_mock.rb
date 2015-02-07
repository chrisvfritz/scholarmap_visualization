require 'sinatra/base'
require 'slim'

class ScholarMapApiMock < Sinatra::Base

  ENDPOINTS = %w(people references characteristics)
  CHARACTERISTIC_TYPES = %w(Method Field Theory Venue)
  METHODS = [ 'Ethnography/Fieldwork', 'Content Analysis' ]
  FIELDS = [ 'Human Computer Interaction', 'Design', 'Information Sciences', 'Health Informatics' ]
  THEORIES = [ 'Cognitive Anthropology', 'Critical Theory', 'Cognitive Artifacts' ]
  DEPARTMENTS = [ 'Media and Information', 'Computer Science' ]
  YEARS = (1700..2100).to_a

  get '/docs' do
    slim :index, locals: { endpoints: ENDPOINTS }
  end

  ENDPOINTS.each do |endpoint|

    get "/#{endpoint}/graphs/force-directed.json" do
      if params[:dynamic]
        dynamic_json_response 200, endpoint.to_sym
      else
        json_response 200, "#{endpoint}.json"
      end
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

  def dynamic_json_response(response_code, type)
    content_type :json
    status response_code

    number_of_nodes = params[:nodes].to_i

    nodes = case type
    when :people
      Array.new(number_of_nodes).map do
        {
          name: (5..20).map { (65 + rand(26)).chr }.join,
          department: DEPARTMENTS.sample
        }
      end
    when :references
      Array.new(number_of_nodes).map do
        {
          citation: (100..300).map { (65 + rand(26)).chr }.join,
          year: YEARS.sample,
          authors: [ (5..20).map { (65 + rand(26)).chr }.join ],
          department: DEPARTMENTS.sample
        }
      end
    when :characteristics
      Array.new(number_of_nodes).map do
        {
          name: (10..30).map { (65 + rand(26)).chr }.join,
          type: CHARACTERISTIC_TYPES.sample
        }
      end
    end

    links = case type
    when :people, :references
      Array.new(number_of_nodes * 2).map do
        {
          source: rand(number_of_nodes),
          target: rand(number_of_nodes),
          similarities: [
            {
              type: 'Methods',
              list: METHODS.sample( rand(METHODS.size) )
            },
            {
              type: 'Fields',
              list: FIELDS.sample( rand(FIELDS.size) )
            },
            {
              type: 'Theories',
              list: THEORIES.sample( rand(THEORIES.size) )
            }
          ]
        }
      end
    when :characteristics
      Array.new(number_of_nodes * 2).map do
        {
          source: rand(number_of_nodes),
          target: rand(number_of_nodes),
          similarities: [
            {
              type: 'People',
              list: Array.new(rand(10)).map { (5..20).map { (65 + rand(26)).chr }.join }
            },
            {
              type: 'References',
              list: Array.new(rand(10)).map { (5..20).map { (65 + rand(26)).chr }.join }
            }
          ]
        }
      end
    end

    {
      nodes: nodes,
      links: links
    }.to_json
  end
end