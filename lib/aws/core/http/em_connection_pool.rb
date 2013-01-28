require 'thread'
require "em-synchrony/em-http"
require 'em-synchrony/thread'

module AWS 
  module Core
    module Http
      class EMConnectionPool
        # Since AWS connections may be to any number of urls, the connection
        # pool is a hash of connection arrays, instead of a simple array like
        # most connection pools        # 
        # Options:
        # * :pool_size - number of connections for each pool
        # * :inactivity_timeout - number of seconds to wait before disconnecting, 
        #   setting to 0 means the connection will not be closed
        # * :pool_timeout - the amount of seconds to block waiting for an available connection, 
        #   because this is blocking it should be an extremely short amount of 
        #   time default to 0.5 seconds, if you need more consider enlarging your pool
        #   instead of raising this number
        # :never_block - if set to true, a connection will always be returned
        def initialize(options={})
          options[:never_block] ||= true
          @pools = {}
          @pool_data = {}
          @pool_size = (options[:pool_size] || 5)
          @never_block = (options[:never_block])
          @inactivity_timeout = (options[:inactivity_timeout].to_i)
          @connect_timeout = options[:connect_timeout]
          @pool_timeout = (options[:pool_timeout] || 0.5) 
          @fibered_mutex = EM::Synchrony::Thread::Mutex.new  # A fiber safe mutex
        end
       
        # Run the block on the retrieved connection. Then return the connection
        # back to the pool.
        def run(url, &block)
          url = url.to_s.split("?")[0].to_s.gsub(/\/$/, "") # homogenize
          connection = santize_connection(connection(url))
          block.call(connection)
        ensure
          return_connection(url,connection) 
        end
        
        private
        # Returns a pool for the associated url
        def available_pools(url)
          add_connection(url) if add_connection?(url)
          @pools[url]
        end
        
        def add_connection?(url)
          (@pool_data[url].nil? || (@pools[url].length == 0 && (@pool_data[url][:current_size] < @pool_size)))
        end
        
        def add_connection(url) 
          AWS.config.logger.info "Adding AWS connection to #{url}"
          add_connection_data(url)
          @pools[url] ||= []
          @pools[url] << new_connection(url)         
          @pools[url]
        end
        
        def add_connection_data(url)
          @pool_data[url] ||= {:current_size => 0} 
          @pool_data[url][:current_size] += 1 
        end
        
        def new_connection(url)
          opts = {:inactivity_timeout => @inactivity_timeout}
          opts[:connect_timeout] = @connect_timeout if @connect_timeout
          EM::HttpRequest.new(url, opts)
        end
        
        # Make sure we have a good connection.
        def santize_connection(connection)
          if connection.conn && connection.conn.error?
            AWS.config.logger.info "Reconnecting to AWS: #{EventMachine::report_connection_error_status(connection.conn.instance_variable_get(:@signature))}"
            connection.conn.close_connection
            connection.instance_variable_set(:@deferred, true)
          end
          connection
        end
              
        # Fetch an available connection or raise an error
        def connection(url)         
          alarm = (Time.now + @pool_timeout)       
          # block until we get an available connection or Timeout::Error   
          loop do
            if alarm <= Time.now
              message = "Could not fetch a free connection in time. Consider increasing your connection pool for em_aws or setting :never_block to true."
              AWS.config.logger.error message
              raise Timeout::Error, message
            end
            connection = fetch_connection(url)
            if connection.nil? && (@never_block)
              AWS.config.logger.info "Adding AWS connection to #{url} for never_block, will not be returned to pool."
              connection = new_connection(url)
            end
            return connection if connection
          end
        end
        
        # Fetch an available connection
        # We pop the last connection increase our chances of getting a live connection
        def fetch_connection(url)         
          @fibered_mutex.synchronize do
            available_pools(url).pop
          end
        end
        
        # If allowed, returns connections to pool end of pool; otherwise closes connection
        def return_connection(url,connection)
          @fibered_mutex.synchronize do
            if (@pools[url].nil? || (@pools[url].length == @pool_size))
              connection.conn.close_connection if connection.conn
            else
              @pools[url] << connection
            end
            @pools[url]
          end
        end
      end
    end
  end
end