#$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
#$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'em-aws'
require 'rspec'
require 'bundler/setup'
require 'logger'

begin
  require 'byebug'
rescue LoadError
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
class StubLogger
  def method_missing(method, *args)
    #we don't care
  end
end


AWS.config(:logger => StubLogger.new)

# EM::HotTub.logger = Logger.new(STDOUT)
# EM::HotTub.trace = true

RSpec.configure do |config|
	
end