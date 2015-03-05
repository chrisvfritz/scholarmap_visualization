source 'https://rubygems.org'
ruby '2.2.0'

gem 'sinatra', '~> 1.4.5'
gem 'rack', '1.5.2' # Locked to avoid bug in rack 1.6 giving unuseful error messages
gem 'thin'
gem 'coffee-script'
gem 'slim'

group :test do
  gem 'rspec', '~> 3.1.0'
  gem 'capybara', '~> 2.4.4'
  gem 'poltergeist'
  gem 'webmock', '~> 1.20.4'
  gem 'simplecov', '~> 0.9.0', require: false
end

group :development do
  gem 'guard-rspec', '~> 4.5.0'
end
