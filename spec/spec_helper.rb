#$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
#$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'em_aws'
require 'aws/core/http/em_http_handler'
require 'rspec'
require 'bundler/setup'
require 'logger'
require 'em-http'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
class StubLogger
  def method_missing(method, *args)
    #we don't care
  end
end
AWS.config(:logger => StubLogger.new)

RSpec.configure do |config|
end