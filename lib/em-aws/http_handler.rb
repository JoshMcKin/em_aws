# http://docs.amazonwebservices.com/AWSRubySDK/latest/
module EventMachine
  module AWS

    # An em-http-request handler for the aws-sdk for fiber based asynchronous ruby application.
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
    #   :pool_size => 10,     # Default is 10
    #   :max_size => 40,      # Maximum size of pool, nil by default so pool can grow to meet concurrency under load
    #   :reap_timeout => 600, # How long to wait to reap connections after load dies down
    #   :async => false))     # If set to true all requests are handle asynchronously and initially return nil
    #
    # EM-AWS exposes all connections options for EM-Http-Request at initialization
    # For more information on available options see https://github.com/igrigorik/em-http-request/wiki/Issuing-Requests#available-connection--request-parameters
    # If Options from the request section of the above link are present, they
    # set on every request but may be over written by the request object
    class HttpHandler < ::AWS::Core::Http::NetHttpHandler

      attr_reader :default_options, :client_options, :pool_options

      # Constructs a new HTTP handler using EM-Synchrony.
      # @param [Hash] options Default options to send to EM-Synchrony on
      # each request. These options will be sent to +get+, +post+,
      # +head+, +put+, or +delete+ when a request is made. Note
      # that +:body+, +:head+, +:parser+, and +:ssl_ca_file+ are
      # ignored. If you need to set the CA file see:
      # https://github.com/igrigorik/em-http-request/wiki/Issuing-Requests#available-connection--request-parameters
      def initialize options = {}
        @default_options = options
        @pool_options = fetch_pool_options
        @client_options = fetch_client_options
        @verify_content_length = options[:verify_response_body_content_length]
        @sessions = EM::HotTub::Sessions.new(pool_options) do |url|
          EM::HttpRequest.new(url,@client_options)
        end
      end

      def handle(request,response,&read_block)
        process_request(request,response,&read_block)
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
        process_request(request,response,true,&read_block)
      end

      private

      REMOVE_OPTIONS = [:pool_size,:max_size, :never_block, :blocking_timeout].freeze

      def fetch_client_options
        co = @default_options.select{ |k,v| !REMOVE_OPTIONS.include?(k) }
        co[:inactivity_timeout] ||= 0.to_i
        co[:connect_timeout] ||= 10
        co[:keepalive] = true unless co.key?(:keepalive)
        co
      end

      def fetch_pool_options
        po = {}
        po[:wait_timeout] = (@default_options[:wait_timeout] || @default_options[:blocking_timeout] || 10).to_i
        po[:size] = (@default_options[:pool_size] || 5).to_i
        po[:size] = 1 if po[:size] < 1
        po[:max_size] = @default_options[:max_size].to_i if @default_options[:max_size]
        po[:reap_timeout] = @default_options[:reap_timeout].to_i if @default_options[:reap_timeout]
        po
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
        opts = @client_options.merge(fetch_headers(request))
        opts[:query] = request.querystring
        if request.body_stream.respond_to?(:path)
          opts[:file] = request.body_stream.path
        else
          opts[:body] = request.body.to_s
        end
        opts[:path] = request.path if request.path
        opts
      end

      def pool(url)
        @sessions.get_or_set(url, @pool_options) { EM::HttpRequest.new(url,@client_options) }
      end

      def fetch_response(request,opts={},&read_block)
        method = "a#{request.http_method}".downcase.to_sym  # aget, apost, aput, adelete, ahead
        url = fetch_url(request)
        result = nil
        if @sessions
          pool(url).run do |connection|
            req = connection.send(method, opts)
            req.stream &read_block if block_given?
            result = EM::Synchrony.sync req unless opts[:async]
          end
        else
          clnt_opts = @client_options.merge(:inactivity_timeout => request.read_timeout)
          req = EM::HttpRequest.new(url,clnt_opts).send(method,opts)
          req.stream &read_block if block_given? and req.response_header.status.to_i < 300
          result = EM::Synchrony.sync req unless opts[:async]
        end
        result
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
        exp_length = determine_expected_content_length(response)
        begin
          http_response = fetch_response(request,opts,&read_block)

          unless opts[:async]
            response.status = http_response.response_header.status.to_i
            raise Timeout::Error if response.status == 0
            response.headers = fetch_response_headers(http_response)
            response.body = http_response.response unless block_given?
          end

          run_check = exp_length && request.http_method != "HEAD" && @verify_content_length
          if run_check && response.body && response.body.bytesize != exp_length
            raise TruncatedBodyError, 'content-length does not match'
          end
        rescue *NETWORK_ERRORS => error
          raise error if block_given?
          response.network_error = error
        end
        nil
      end
    end
  end
end
