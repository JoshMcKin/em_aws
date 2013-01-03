require 'thread'
require "em-synchrony/em-http"
require 'em-synchrony/thread'

module AWS 
  module Core
    module Http
      class EMConnectionPool
        # Since AWS connections may be to any number of urls, the connection
        # pool is a hash of connection arrays, instead of a simple array like
        # most connection pools
        # Stores data concerning pools, like current size, last fetched
        # 
        # OPTIONS
        # * :pool_size - number of connections for each pool
        # * :inactivity_timeout - number of seconds to wait before disconnecting, 
        # setting to 0 means the connection will not be closed
        # * :pool_timeout - the amount of seconds to block waiting for an available connection, 
        # because this is blocking it should be an extremely short amount of 
        # time default to 0.5 seconds, if you need more consider enlarging your pool
        # instead of raising this number
        # :never_block - if set to true, a connection will always be returned
        def initialize(options={})
          options[:never_block] ||= true
          @pools = {}
          @pool_data = {}
          @pool_size = (options[:pool_size] || 5)
          @never_block = (options[:never_block])
          @inactivity_timeout = (options[:inactivity_timeout] || 0)
          @pool_timeout = (options[:pool_timeout] || 0.5) 
        end
        
        def _fiber_mutex
          @fibered_mutex ||= EM::Synchrony::Thread::Mutex.new
        end
        
        def available_pools(url)
          _fiber_mutex.synchronize do
            add_connection(url) if add_connection?(url)
            @pools[url]
          end
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
          EM::HttpRequest.new(url, :inactivity_timeout => @inactivity_timeout)
        end
        
        # run the block on the retrieved connection, then return the connection
        # back to the pool.
        def run(url, &block)
          connection = santize_connection(fetch_connection(url))
          block.call(connection)
        ensure
          return_connection(url,connection) 
        end
        
        # return an available connection
        def fetch_connection(url)         
          connection = nil
          alarm = (Time.now + @pool_timeout)       
          # block until we get an available connection or Timeout::Error     
          while connection.nil?
            if alarm <= Time.now
              message = "Could not fetch a free connection in time. Consider increasing your connection pool for em_aws or setting :never_block to true."
              AWS.config.logger.error message
              raise Timeout::Error, message
            end
            connection = available_pools(url).shift
            if connection.nil? && (@never_block)
              AWS.config.logger.info "Adding AWS connection to #{url} for never_block, will not be returned to pool."
              connection = new_connection(url)
            end
          end
          connection    
        end
        
        # Make sure we have a good connection. This should not be necessary 
        # in em-http-request master, but better safe than sorry...
        def santize_connection(connection)
          if connection.conn && connection.conn.error?
            AWS.config.logger.info "Reconnecting to AWS: #{EventMachine::report_connection_error_status(connection.conn.instance_variable_get(:@signature))}"
            connection.conn.close_connection
            connection.instance_variable_set(:@deferred, true)
          end
          connection
        end
        
        def return_connection(url,connection)
          _fiber_mutex.synchronize do
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
