# http://docs.amazonwebservices.com/AWSRubySDK/latest/
require 'hot_tub'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'em-synchrony/thread'
module AWS
  module Core
    module Http

      # An EM-Synchrony implementation for Fiber based asynchronous ruby application.
      # See https://github.com/igrigorik/async-rails and
      # http://www.mikeperham.com/2010/04/03/introducing-phat-an-asynchronous-rails-app/
      # for examples of Aync-Rails application
      #
      # In Rails add the following to your aws.rb initializer
      #
      # require 'aws-sdk'
      # require 'aws/core/http/em_http_handler'
      # AWS.config(
      #   :http_handler => AWS::Http::EMHttpHandler.new(
      #     :proxy => {:host => '127.0.0.1',    # proxy address
      #        :port => 9000,                 # proxy port
      #        :type => :socks5},
      #   :pool_size => 20, # not set by default which disables connection pooling
      #   :async => false # if set to true all requests are handle asynchronously and initially return nil
      #   }))
      #
      # EM-AWS exposes all connections options for EM-Http-Request at initialization
      # For more information on available options see https://github.com/igrigorik/em-http-request/wiki/Issuing-Requests#available-connection--request-parameters
      # If Options from the request section of the above link are present set on every request
      # but may be over written by the request object
      class EMHttpHandler

        EM_PASS_THROUGH_ERRORS = [
          NoMethodError, FloatDomainError, TypeError, NotImplementedError,
          SystemExit, Interrupt, SyntaxError, RangeError, NoMemoryError,
          ArgumentError, ZeroDivisionError, LoadError, NameError,
          LocalJumpError, SignalException, ScriptError,
          SystemStackError, RegexpError, IndexError,
        ]
        # @return [Hash] The default options to send to EM-Synchrony on each request.
        attr_reader :default_options

        # Constructs a new HTTP handler using EM-Synchrony.
        # @param [Hash] options Default options to send to EM-Synchrony on
        # each request. These options will be sent to +get+, +post+,
        # +head+, +put+, or +delete+ when a request is made. Note
        # that +:body+, +:head+, +:parser+, and +:ssl_ca_file+ are
        # ignored. If you need to set the CA file, you should use the
        # +:ssl_ca_file+ option to {AWS.config} or
        # {AWS::Configuration} instead.
        def initialize options = {}
          @default_options = options
          if with_pool?
            @pool = HotTub::Session.new(pool_options) { |url| EM::HttpRequest.new(url,client_options)}
          end
        end

        def client_options
          @client_options ||= fetch_client_options
        end
        
        def pool_options
          @pool_options ||= fetch_pool_options
        end

        def handle(request,response,&read_block)
          if EM::reactor_running?
            process_request(request,response,&read_block)
          else
            EM.synchrony do
              process_request(request,response,&read_block)
              @pool.close_all if @pool
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
              @pool.close_all if @pool
              EM.stop
            end
          end
        end

        def with_pool?
          (default_options[:pool_size].to_i > 0)
        end

        private

        def fetch_client_options
          co = ({} || default_options.dup)
          co.delete(:size)
          co.delete(:never_block)
          co.delete(:blocking_timeout)
          co[:inactivity_timeout] ||= 0
          co[:connect_timeout] ||= 10
          co[:keepalive] = true if with_pool?
          co
        end

        def fetch_pool_options
          {
            :with_pool => true,
            :size => ((default_options[:pool_size].to_i || 5)),
            :never_block => (default_options[:never_block].nil? ? true : default_options[:never_block]),
            :blocking_timeout => (default_options[:blocking_timeout] || 10)
          }
        end

        def fetch_url(request)
          "#{(request.use_ssl? ? "https" : "http")}://#{request.host}:#{request.port}"
        end

        def fetch_headers(request)
          headers = { 'content-type' => '' }
          request.headers.each_pair do |key,value|
            headers[key] = value.to_s
          end
          {:head => headers}
        end

        def fetch_request_options(request)
          opts = default_options.merge(fetch_headers(request))
            opts[:query] = request.querystring
          if request.body_stream.respond_to?(:path)
            opts[:file] = request.body_stream.path
          else
            opts[:body] = request.body.to_s
          end
          opts[:path] = request.path if request.path
          opts
        end

        def fetch_response(request,opts={},&read_block)
          method = "a#{request.http_method}".downcase.to_sym  # aget, apost, aput, adelete, ahead
          url = fetch_url(request)
          if @pool
            @pool.run(url) do |connection|
              req = connection.send(method, opts)
              req.stream &read_block if block_given?
              return  EM::Synchrony.sync req unless opts[:async]
            end
          else
            clnt_opts = client_options.merge(:inactivity_timeout => request.read_timeout)
            req = EM::HttpRequest.new(url,clnt_opts).send(method,opts)
            req.stream &read_block if block_given?
            return  EM::Synchrony.sync req unless opts[:async]
          end
          nil
        end

        # AWS needs all header keys downcased and values need to be arrays
        def fetch_response_headers(response)
          response_headers = response.response_header.raw.to_hash
          aws_headers = {}
          response_headers.each_pair do  |k,v|
            key = k.downcase
            #['x-amz-crc32', 'x-amz-expiration','x-amz-restore','x-amzn-errortype']
            if v.is_a?(Array)
              aws_headers[key] = v
            else
              aws_headers[key] = [v]
            end
          end
          response_headers.merge(aws_headers)
        end

        # Builds and attempts the request. Occasionally under load em-http-request
        # em-http-request returns a status of 0 for various http timeouts, see:
        # https://github.com/igrigorik/em-http-request/issues/76
        # https://github.com/eventmachine/eventmachine/issues/175
        def process_request(request,response,async=false,&read_block)
          opts = fetch_request_options(request)
          opts[:async] = (async || opts[:async])
          begin
            http_response = fetch_response(request,opts,&read_block)
            unless opts[:async]
              response.status = http_response.response_header.status.to_i
              raise Timeout::Error if response.status == 0
              response.headers = fetch_response_headers(http_response)
              response.body = http_response.response
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
