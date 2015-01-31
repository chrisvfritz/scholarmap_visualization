require File.join( File.dirname(__FILE__), 'app' )
require File.join( File.dirname(__FILE__), 'spec/support/scholar_map_api_mock' )

run Rack::URLMap.new(
  '/' => ScholarMapViz.new,
  ScholarMapViz::API_BASE => ScholarMapApiMock.new
)
