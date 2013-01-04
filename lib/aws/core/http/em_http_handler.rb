# http://docs.amazonwebservices.com/AWSRubySDK/latest/
require "em-synchrony"
require "em-synchrony/em-http"
require 'em-synchrony/thread'
module AWS
  module Core
    module Http
      
      # An EM-Synchrony implementation for Fiber based asynchronous ruby application.
      # See https://github.com/igrigorik/async-rails and 
      # http://www.mikeperham.com/2010/04/03/introducing-phat-an-asynchronous-rails-app/
      # for examples of Aync-Rails application
      # 
      # In Rails add the following to you various environment files:
      #
      # require 'aws-sdk'
      # require 'aws/core/http/em_http_handler'
      # AWS.config(
      #   :http_handler => AWS::Http::EMHttpHandler.new(
      #   :proxy => {:host => "http://myproxy.com",
      #   :port => 80,
      #   :pool_size => 20 # set to nil or 0 to not use pool
      #   }))
      #
      class EMHttpHandler
        # @return [Hash] The default options to send to EM-Synchrony on each
        # request.
        attr_reader :default_request_options
        attr_accessor :status_0_retries      
        # Constructs a new HTTP handler using EM-Synchrony.
        #
        # @param [Hash] options Default options to send to EM-Synchrony on
        # each request. These options will be sent to +get+, +post+,
        # +head+, +put+, or +delete+ when a request is made. Note
        # that +:body+, +:head+, +:parser+, and +:ssl_ca_file+ are
        # ignored. If you need to set the CA file, you should use the
        # +:ssl_ca_file+ option to {AWS.config} or
        # {AWS::Configuration} instead.
        def initialize options = {}
          #puts "Using EM-Synchrony for AWS requests"
          @default_request_options = options
          @pool = EMConnectionPool.new(options) if options[:pool_size].to_i > 0
          @status_0_retries = 2 # set to 0 for no retries
        end
        
        def fetch_url(request)
          url = nil
          if request.use_ssl?
            url = "https://#{request.host}:443#{request.uri}"
          else
            url = "http://#{request.host}#{request.uri}"
          end
          url
        end
                   
        def fetch_headers(request)
          headers = { 'content-type' => '' }
          request.headers.each_pair do |key,value|
            headers[key] = value.to_s
          end
          {:head => headers}
        end
        
        def fetch_proxy(request)
          opts={}
          if request.proxy_uri     
            opts[:proxy] = {:host => request.proxy_uri.host,:port => request.proxy_uri.port}
          end
          opts
        end
          
        def fetch_ssl(request)
          opts = {}
          if request.use_ssl? && request.ssl_verify_peer?
            opts[:private_key_file] = request.ssl_ca_file 
            opts[:cert_chain_file]= request.ssl_ca_file 
          end
          opts
        end
        
        def request_options(request)
          fetch_headers(request).
            merge(fetch_proxy(request)).
            merge(fetch_ssl(request))
        end
        
        def fetch_response(url,method,opts={})
          return EM::HttpRequest.new(url).send(method, opts) unless @pool
          @pool.run(url) do |connection|
            connection.send(method, {:keepalive => true}.merge(opts))
          end
        end 
    
        def handle(request,response)
          if EM::reactor_running? 
            handle_it(request, response)    
          else
            EM.synchrony do
              handle_it(request, response)
              EM.stop
            end
          end
        end
        
        # Builds and attempts the request. Occasionally under load em-http-request
        # returns a status of 0 with nil for header and body, in such situations
        # we retry as many times as status_0_retries is set. If our retries exceed
        # status_0_retries we assume there is a network error
        def handle_it(request, response, retries=0)      
          method = request.http_method.downcase.to_sym  # get, post, put, delete, head
          opts = default_request_options.merge(request_options(request))  
          if (method == :get)
            opts[:query] = request.body
          else
            opts[:body] = request.body
          end
          url = fetch_url(request)
          begin
            http_response = fetch_response(url,method,opts)                  
            response.status = http_response.response_header.status.to_i
            if response.status == 0
              if retries <= status_0_retries.to_i
                handle_it(request, response, (retries + 1))
              else
                response.network_error = true  
              end
            else
              response.headers = to_aws_headers(http_response.response_header.raw.to_hash)
              response.body = http_response.response if response.status < 300
            end
          rescue *AWS::Core::Http::NetHttpHandler::NETWORK_ERRORS
            response.network_error = true  
          end
        end
        
        # AWS needs all headers downcased, and for some reason x-amz-expiration and
        # x-amz-restore need to be arrays
        def to_aws_headers(response_headers)
          aws_headers = {}
          response_headers.each_pair do  |k,v|
            key = k.downcase
            if (key == "x-amz-expiration" || key == 'x-amz-restore')
              aws_headers[key] = [v]
            else
              aws_headers[key] = v
            end
          end
          response_headers.merge(aws_headers)
        end
      end
    end
  end

  # We move this from AWS::Http to AWS::Core::Http, but we want the
  # previous default handler to remain accessible from its old namespace
  # @private
  module Http
    class EMHttpHandler < Core::Http::EMHttpHandler; end
  end
end