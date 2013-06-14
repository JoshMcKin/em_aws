require 'em_aws/patches'
require 'aws-sdk'
require 'em_aws/version'
require 'em-http'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'aws/core/http/em_http_handler'
require 'hot_tub'

AWS.eager_autoload! # lazy load isn't thread safe
HotTub.logger = AWS.config.logger if AWS.config.logger
module EmAws;end
