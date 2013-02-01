# Copyright 2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'spec_helper'
module AWS::Core
  module Http
    class EMFooIO
      def path
        "/my_path/test.text"
      end
    end
    describe EMHttpHandler do
    
      let(:handler) { EMHttpHandler.new(default_request_options) }

      let(:default_request_options) { {} }

      let(:req) do
        r = Http::Request.new
        r.host = "foo.bar.com"
        r.uri = "/my_path/?foo=bar"
        r.body_stream = StringIO.new("myStringIO")
        r
      end

      let(:resp) { Http::Response.new }

      let(:em_http_options) do
        options = nil
        EMHttpHandler.should_receive(:fetch_response).with do |url, method,opts|
          options = opts
          double("http response",
            :response => "<foo/>",
            :code => 200,
            :to_hash => {})
        end
        handler.handle(req, resp)
        options
      end
        
      it 'should be accessible from AWS as well as AWS::Core' do
        AWS::Http::EMHttpHandler.new.should 
        be_an(AWS::Core::Http::EMHttpHandler)
      end

      describe '#handle' do
        context 'timeouts' do
          it 'should rescue Timeout::Error' do
            handler.stub(:fetch_response).
              and_raise(Timeout::Error)
            lambda { handler.handle(req, resp) }.
              should_not raise_error
          end

          it 'should rescue Errno::ETIMEDOUT' do
            handler.stub(:fetch_response).
              and_raise(Errno::ETIMEDOUT)
            lambda { handler.handle(req, resp) }.
              should_not raise_error
          end

          it 'should indicate that there was a network_error' do
            handler.stub(:fetch_response).
              and_raise(Errno::ETIMEDOUT)
            handler.handle(req, resp)
            resp.network_error?.should be_true
          end
        end

        context 'default request options' do
          before(:each) do
            handler.stub(:default_request_options).and_return({ :foo => "BAR",
                :private_key_file => "blarg" })
          end

          it 'passes extra options through to synchrony' do
            handler.default_request_options[:foo].should == "BAR"
          end

          it 'uses the default when the request option is not set' do
            #puts handler.default_request_options
            handler.default_request_options[:private_key_file].should == "blarg"
          end         
        end   
      end
      describe '#process_request' do
        context 'too many retries' do
          it "should have network error" do
            EM.synchrony do
              resp.stub(:status).and_return(0)
              handler.send(:process_request,(req),(resp),false,3)
              resp.network_error?.should be_true
              EM.stop
            end
          end
        end
      end
      describe '#fetch_request_options' do
        
        it "should set :query and :body to request.querystring" do
          opts = handler.send(:fetch_request_options,(req))
          opts[:query].should eql(req.querystring)
        end
        
        it "should set :path to request.path" do
          opts = handler.send(:fetch_request_options,(req))
          opts[:path].should eql(req.path)
        end  
        context "request.body_stream is a StringIO" do
          it "should set :body to request.body_stream" do
            opts = handler.send(:fetch_request_options,(req))
            opts[:body].should eql("myStringIO")
          end
        end
        context "request.body_stream is an object that responds to :path" do
          it "should set :file to object.path " do
            my_io = EMFooIO.new
            req.stub(:body_stream).and_return(my_io)
            opts = handler.send(:fetch_request_options,(req))
            opts[:file].should eql(my_io.path)
          end
        end
      end
      describe '#fetch_proxy' do
        context ':proxy_uri' do
          it 'passes proxy address and port from the request' do
            req.proxy_uri = URI.parse('https://user:pass@proxy.com:443/path?query')
            handler.send(:fetch_proxy,(req))[:proxy][:host].should == 'proxy.com'
            handler.send(:fetch_proxy,(req))[:proxy][:port].should == 443
          end
        end
        
        describe '#fetch_ssl' do
          it 'prefers the request option when set' do
            req.use_ssl = true
            req.ssl_verify_peer = true
            req.ssl_ca_file = "something"
            handler.send(:fetch_ssl,(req))[:private_key_file].should == "something"
            handler.send(:fetch_ssl,(req))[:cert_chain_file].should == "something"
          end
           
          context 'CA cert path' do
            context 'use_ssl? is true' do

              before(:each) { req.use_ssl = true }

              context 'ssl_verify_peer? is true' do

                before(:each) do
                  req.ssl_verify_peer = true
                  req.ssl_ca_file = "foobar.txt"
                end

                it 'should use the ssl_ca_file attribute of the request' do
                  handler.send(:fetch_ssl,(req))[:private_key_file].should == "foobar.txt"
                end
                  
                it 'should use the ssl_ca_file attribute of the request' do
                  handler.send(:fetch_ssl,(req))[:cert_chain_file].should == "foobar.txt"
                end
              end

              it 'should not set the ssl_ca_file option without ssl_verify_peer?' do
                handler.send(:fetch_ssl,(req)).should_not include(:private_key_file)
              end
            end

            it 'should not set the ssl_ca_file option without use_ssl?' do
              handler.send(:fetch_ssl,(req)).should_not include(:private_key_file)
            end
          end
        end      
      end    
    end
  end
end