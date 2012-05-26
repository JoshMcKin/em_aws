# To change this template, choose Tools | Templates
# and open the template in the editor.

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
      end
    end
  end
end

