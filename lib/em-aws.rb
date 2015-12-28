require 'em-http'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'em-hot_tub'
require 'aws-sdk-v1'
require_relative 'em-aws/patches'
require_relative 'em-aws/version'
require_relative 'em-aws/http_handler'

AWS.eager_autoload! # lazy load isn't thread safe

module EventMachine
  module AWS;end
end

# Backwards compatibility
EmAws = EventMachine::AWS