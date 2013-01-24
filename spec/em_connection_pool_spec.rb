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
        
        describe '#add_connection?' do
          it "should be true if @pool_data does not have data for the url"do
            @em_connection_pool.send(:add_connection?,"http://www.testurl123.com/").should be_true 
          end
      
          it "should be true if @pool_data has data but the number of connnections has not reached the pool_size" do
            @em_connection_pool.instance_variable_set(:@pools,{"http://www.testurl123.com/" => ["connection"]})
            @em_connection_pool.send(:add_connection?,"http://www.testurl123.com/").should be_true 
          end
          
          it "should be false pool has reached pool_size" do
            @em_connection_pool.instance_variable_set(:@pools,
              {"http://www.testurl123.com/" => ["connection","connection","connection","connection","connection"]})
            @em_connection_pool.send(:add_connection?,"http://www.testurl123.com/").should be_true 
          end
        end
        
        describe '#add_connection' do
          it "should add connections for supplied url"do
            @em_connection_pool.send(:add_connection,"http://www.testurl123.com/") 
            @em_connection_pool.instance_variable_get(:@pools)["http://www.testurl123.com/"].should_not be_nil
          end
        end   
        
        describe '#connection' do
          it "should raise Timeout::Error if an available is not found in time"do
            @em_connection_pool.stub(:available_pools).and_return([])
            @em_connection_pool.instance_variable_set(:@never_block, false)
            lambda { @em_connection_pool.send(:connection,'http://some_url.com')}.should raise_error(Timeout::Error)
          end
        end

        context 'integration test with parallel requests' do
          # 10 parallel requests
          
          it "should work" do             
            @requests_made = []
            EM.synchrony do 
              @em_connection_pool.instance_variable_set(:@never_block, true)
              fibers = []  
              10.times do 
                fibers << Fiber.new do                           
                @em_connection_pool.run "http://www.testurl123.com/" do |connection|                 
                  @requests_made << connection.get(:keepalive => true).response_header.status    
                  end  
                end  
              end 
              
              fibers.each do |f|
               f.resume
              end
        
              loop do  
                done = true
                fibers.each do |f|
                  done = false if f.alive?
                end
                if done
                  break
                else
                  EM::Synchrony.sleep(0.01)   
                end
              end
    
              @requests_made.length.should eql(10)
              @em_connection_pool.instance_variable_get(:@pools)["http://www.testurl123.com/"].length.should eql(@em_connection_pool.instance_variable_get(:@pool_size))              

              EM.stop
            end
          end          
        end
      end
    end
  end
end