require 'simplecov'
SimpleCov.start

require 'capybara/rspec'
require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist

require 'webmock/rspec'

require_relative '../app'
require_relative 'support/scholar_map_api_mock'

ScholarMapViz.environment = :test
Bundler.require :default, ScholarMapViz.environment

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    /codeclimate.com/
  ]
)

Capybara.app = Rack::URLMap.new(
  '/' => ScholarMapViz.new,
  ScholarMapViz::API_BASE => ScholarMapApiMock.new
)
