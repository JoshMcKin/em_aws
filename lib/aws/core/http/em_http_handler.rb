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
      #   :pool_size => 20, # not set by default which disables connection pooling
      #   :async => false # if set to true all requests are handle asynchronously and initially return nil
      #   }))
      class EMHttpHandler
        
        EM_PASS_THROUGH_ERRORS = [
          NoMethodError, FloatDomainError, TypeError, NotImplementedError,
          SystemExit, Interrupt, SyntaxError, RangeError, NoMemoryError,
          ArgumentError, ZeroDivisionError, LoadError, NameError,
          LocalJumpError, SignalException, ScriptError,
          SystemStackError, RegexpError, IndexError,
        ]
        # @return [Hash] The default options to send to EM-Synchrony on each request.
        attr_reader :default_request_options
        attr_accessor :status_0_retries  
        
        # Constructs a new HTTP handler using EM-Synchrony.
        # @param [Hash] options Default options to send to EM-Synchrony on
        # each request. These options will be sent to +get+, +post+,
        # +head+, +put+, or +delete+ when a request is made. Note
        # that +:body+, +:head+, +:parser+, and +:ssl_ca_file+ are
        # ignored. If you need to set the CA file, you should use the
        # +:ssl_ca_file+ option to {AWS.config} or
        # {AWS::Configuration} instead.
        def initialize options = {}
          @default_request_options = options
          @pool = EMConnectionPool.new(options) if options[:pool_size].to_i > 0
          @status_0_retries = 2 # set to 0 for no retries
        end 
    
        def handle(request,response,&read_block)
          if EM::reactor_running? 
            process_request(request,response,&read_block)    
          else
            EM.synchrony do
              process_request(request,response,&read_block)
              EM.stop
            end
          end
        end
        
        # If the request option :async are set to true that request will  handled 
        # asynchronously returning nil initially and processing in the background 
        # managed by EM-Synchrony. If the client option :async all requests will 
        # be handled asynchronously.
        # EX:
        #     EM.synchrony do
        #       s3 = AWS::S3.new
        #       s3.obj.write('test', :async => true) => nil
        #       EM::Synchrony.sleep(2)
        #       s3.obj.read => # 'test'
        #       EM.stop
        #     end
        def handle_async(request,response,handle,&read_block)
          if EM::reactor_running? 
            process_request(request,response,true,&read_block)    
          else
            EM.synchrony do
              process_request(request,response,true,&read_block)
              EM.stop
            end
          end
        end
        
        private
        
        def fetch_url(request)
          url = nil
          if request.use_ssl?
            url = "https://#{request.host}:443"
          else
            url = "http://#{request.host}"
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
        
        def fetch_request_options(request)
          opts = default_request_options.
            merge(fetch_headers(request).
              merge(fetch_proxy(request)).
              merge(fetch_ssl(request)))  
          opts[:query] = opts[:body] = request.querystring
          opts[:path] = request.path if request.path
          opts
        end
        
        def fetch_response(url,method,opts={},&read_block)
          if @pool
            @pool.run(url) do |connection|
              req = connection.send(method, {:keepalive => true}.merge(opts))
              req.stream &read_block if block_given?
              return  EM::Synchrony.sync req unless opts[:async]
            end
          else
            req = EM::HttpRequest.new(url).send(method,opts)
            req.stream &read_block if block_given?
            return  EM::Synchrony.sync req unless opts[:async]
          end
          nil
        end
            
        # AWS needs all headers downcased, and for some reason x-amz-expiration and
        # x-amz-restore need to be arrays
        def fetch_response_headers(response)
          response_headers = response.response_header.raw.to_hash
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
        
        # Builds and attempts the request. Occasionally under load em-http-request
        # returns a status of 0 with nil for header and body, in such situations
        # we retry as many times as status_0_retries is set. If our retries exceed
        # status_0_retries we assume there is a network error
        def process_request(request,response,async=false,retries=0,&read_block)      
          method = "a#{request.http_method}".downcase.to_sym  # aget, apost, aput, adelete, ahead
          opts = fetch_request_options(request)
          opts[:async] = (async || opts[:async])
          url = fetch_url(request)
          begin
            http_response = fetch_response(url,method,opts,&read_block) 
            unless opts[:async]
              response.status = http_response.response_header.status.to_i
              if response.status == 0
                if retries <= status_0_retries.to_i
                  process_request(request,response,(retries + 1),&read_block)
                else
                  response.network_error = true  
                end
              else
                response.headers = fetch_response_headers(http_response)
                response.body = http_response.response
              end
            end
          rescue Timeout::Error => error
            response.network_error = error
          rescue *EM_PASS_THROUGH_ERRORS => error
            raise error
          rescue Exception => error
            response.network_error = error
          end
          nil
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