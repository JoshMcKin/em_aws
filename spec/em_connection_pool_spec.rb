# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'thread'
require "em-synchrony"
require "em-synchrony/em-http"
require 'spec_helper'
module AWS 
  module Core
    module Http
      describe EMConnectionPool do
        before(:each) do
          @em_connection_pool = EMConnectionPool.new
        end

        context 'default configuration' do
          it "should have @pool_size of 5" do
            @em_connection_pool.instance_variable_get(:@pool_size).should eql(5)
          end
    
          it "should have @inactivity_timeout of 0" do
            @em_connection_pool.instance_variable_get(:@inactivity_timeout).should eql(0)
          end
    
          it "should have @pool_timeout of 0" do
            @em_connection_pool.instance_variable_get(:@pool_timeout).should eql(0.5)
          end
        end
        
        describe '#fetch_connection' do
          it "should raise Timeout::Error if an available is not found in time"do
            @em_connection_pool.stub(:available_pools).and_return([])
            lambda { @em_connection_pool.fetch_connection('some_url.com')}.should raise_error(Timeout::Error)
          end
        end
        require 'httparty'
        context 'multi-fibering' do
          # Pretty sure this is how you would do threads with fibers
          @em_connection_pool.instance_variable_set(:@never_block, true)
          it "should be thread safe" do             
            @requests_made = []

            fibers = []  
            10.times do 
              fibers << Fiber.new do
                EM.synchrony do                 
                  @r = nil
                  @em_connection_pool.run "http://www.testbadurl123.com/" do |connection|                 
                    @r = connection.get({:keepalive => true}).response_header.status.to_i
                  end
                  @requests_made << @r
                  Fiber.yield EM.stop
                end
                    
              end 
                  
              fibers.each do |f| 
                f.resume if f.alive?
              end
                  
            end
            # Make sure all our request were made
            @requests_made.length.should eql(10)
            
            # If we were not thread safe the number of connections would not be 5
            @em_connection_pool.instance_variable_get(:@pools)["http://www.testbadurl123.com/"].length.should eql(@em_connection_pool.instance_variable_get(:@pool_size))              
          end          
        end
      end
    end
  end
end