if ENV['CODECLIMATE_REPO_TOKEN']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
else
  require 'simplecov'
  SimpleCov.start
end

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
