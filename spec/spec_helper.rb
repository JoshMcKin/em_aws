#$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
#$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'em_aws'
require 'rspec'
require 'bundler/setup'
require 'logger'



# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

AWS.config(:logger => Logger.new(STDERR))
RSpec.configure do |config|


end

