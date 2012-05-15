require 'aws-sdk'
require 'em_aws/version'
require 'em-http'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'aws/core/autoloader'

AWS.eager_autoload! # lazy load isn't thread safe
module AWS
  module Core
    module Http
      AWS.register_autoloads(self) do
        autoload :EMHttpHandler,   'em_http_handler'
      end
    end
  end

  # the http party handler should still be accessible from its old namespace
  module Http
    AWS.register_autoloads(self, 'aws/core/http') do
      autoload :HTTPartyHandler, 'httparty_handler'
    end
  end
end
