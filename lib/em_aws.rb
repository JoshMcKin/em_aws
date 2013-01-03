require 'em_aws/patches'
require 'aws-sdk'
require 'em_aws/version'
require 'em-http'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'aws/core/autoloader'
require 'aws/core/http/em_connection_pool'
require 'aws/core/http/em_http_handler'

AWS.eager_autoload! # lazy load isn't thread safe
module EmAws;end
