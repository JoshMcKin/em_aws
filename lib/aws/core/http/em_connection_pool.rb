require "em-synchrony/em-http"
require 'em-synchrony/thread'

module AWS 
  module Core
    module Http
      class EMConnectionPool
        # Since AWS connections may be to any number of urls, the connection
        # pool is a hash of connection arrays, instead of a simple array like
        # most connection pools
        
        @@pools = {}
        
        # OPTIONS
        # * :pool_size - number of connections for each pool
        # * :inactivity_timeout - number of seconds to wait before disconnecting, 
        # setting to 0 means the connection will not be closed
        # * :pool_timeout - the amount of seconds to block waiting for an availble connection, 
        # because this is blocking it should be an extremely short amount of 
        # time default to 0.5 seconds, if you need more consider enlarging your pool
        # instead of raising this number
        def initialize(options={})
          @pool_size = (options[:pool_size] || 5)
          @inactivity_timeout = (options[:inactivity_timeout] || 0)
          @pool_timeout = (options[:pool_timeout] || 0.5) 
        end      
        
        def available_pools(url)
          add_connection(url) if (@@pool_data[url].nil? || (@@pools[url].empty? && @@pool_data[url][:current_size] < @pool_size))
          @@pools[url]
        end
        
        def add_connection(url)
          puts AWS.config.logger.info "Adding AWS connection to #{url}"
          @@pools[url] ||= []
          @@pool_data[url] ||= {:current_size => 0}
          @@pools[url] << EM::HttpRequest.new(url, :inactivity_timeout => @inactivity_timeout)
          @@pool_data[url][:current_size] += 1 
          @@pools[url]
        end
        
        # run the block on the retrieved connection, then return the connection
        # back to the pool.
        def run(url, &block)
          connection = fetch_connection(url)
          block.call(connection)
        ensure
          return_connection(url,connection) 
        end
        
        # return an available connection
        def fetch_connection(url) 
          alarm = (Time.now + @pool_timeout)
          connection = nil
          # block until we get an available connection or Timeout::Error
          while connection.nil?
            raise Timeout::Error, "Could not fetch a free connection in time. Consider increasing your connection pool for em_aws." if alarm <= Time.now
            connection = available_pools(url).shift
          end  
          santize_connection(connection)
        end
        
        # Make sure we have a good connection. This should not be nesseccary 
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
          @@pools[url] << connection
        end
      end
    end
  end
end