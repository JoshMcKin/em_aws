# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'thread'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
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
        
        context 'multi-threading' do
          # Pretty sure this is how you would do threads with fibers
          it "should be thread safe" do             
            @threads = []
            @request_made = []
            50.times do |i|
              @threads << Thread.new do
                fibers = []
                3.times do 
                  fibers << Fiber.new do
                    EM.synchrony do
                      @em_connection_pool.stub(:new_connection).and_return(1)
                      @em_connection_pool.stub(:santize_connection).and_return(1)
                      @em_connection_pool.run("http://test_url.com") do |connection|
                        @request_made << connection
                      end
                      EM.stop
                    end 
                  end
                end
                fibers.each do |t| 
                  t.resume
                end
              end
            end
            sleep(1)
            @threads.each do |t| 
              t.join
            end
            # Make sure all our request were made
            @request_made.length.should eql(150)
            # If we were not thread safe the number of connections would not be 5
            @em_connection_pool.instance_variable_get(:@pools)["http://test_url.com"].length.should eql(@em_connection_pool.instance_variable_get(:@pool_size))              
          end          
        end
      end
    end
  end
end

