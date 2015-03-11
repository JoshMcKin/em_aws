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
require 'eventmachine'
require 'evma_httpserver'
module AWS::Core
  module Http
    class EMFooIO
      def path
        "/my_path/test.text"
      end
    end

    # A slow server for testing timeout,
    # borrowed from: http://www.igvita.com/2008/05/27/ruby-eventmachine-the-speed-demon/
    class SlowServer < EventMachine::Connection
      include EventMachine::HttpServer

      def process_http_request
        resp = EventMachine::DelegatedHttpResponse.new( self )

        sleep 2 # Simulate a long running request

        resp.status = 200
        resp.content = "Hello World!"
        resp.send_response
      end
    end

    describe EMHttpHandler do
      let(:handler) { EMHttpHandler.new(default_request_options) }

      let(:default_request_options) { Hash.new }

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
        EMHttpHandler.should_receive(:fetch_response).with do |url, _, opts|
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
        expect(AWS::Http::EMHttpHandler.new).to be_an(AWS::Core::Http::EMHttpHandler)
      end

      it "should not timeout" do
        EM.synchrony do
          response = Http::Response.new
          request = Http::Request.new
          request.host = "127.0.0.1"
          request.port = "8081"
          request.uri = "/"
          request.body_stream = StringIO.new("myStringIO")

          # turn on our test server
          EventMachine::run do
            EventMachine::start_server request.host, request.port, SlowServer
          end

          allow(handler).to receive(:fetch_url).and_return("http://127.0.0.1:8081")

          handler.handle(request,response)

          expect(response.network_error).to be_nil

          EM.stop
        end
      end

      it "should timeout after 0.1 seconds" do
        EM.synchrony do
          response = Http::Response.new
          request = Http::Request.new
          request.host = "127.0.0.1"
          request.port = "8081"
          request.uri = "/"
          request.body_stream = StringIO.new("myStringIO")

          # turn on our test server
          EventMachine::run do
            EventMachine::start_server request.host, request.port, SlowServer
          end

          allow(handler).to receive(:fetch_url).and_return("http://127.0.0.1:8081")
          allow(request).to receive(:read_timeout).and_return(0.01)
          allow(handler).to receive(:connect_timeout).and_return(1) #just to speed up the test

          handler.handle(request,response)

          expect(response.network_error).to be_a(Timeout::Error)

          EM.stop
        end
      end

      describe '#handle' do
        context 'timeouts' do
          it 'should rescue Timeout::Error' do
            allow(handler).to receive(:fetch_response).and_raise(Timeout::Error)

            expect {
              handler.handle(req, resp)
            }.to_not raise_error
          end

          it 'should rescue Errno::ETIMEDOUT' do
            allow(handler).to receive(:fetch_response).and_raise(Errno::ETIMEDOUT)

            expect {
              handler.handle(req, resp)
            }.to_not raise_error
          end

          it 'should indicate that there was a network_error' do
            allow(handler).to receive(:fetch_response).and_raise(Errno::ETIMEDOUT)

            handler.handle(req, resp)

            expect(resp).to be_network_error
          end
        end

        context 'default request options' do
          before(:each) do
            allow(handler).to receive(:default_request_options).and_return(:foo => "BAR", :private_key_file => "blarg")
          end

          it 'passes extra options through to synchrony' do
            expect(handler.default_request_options[:foo]).to eql("BAR")
          end

          it 'uses the default when the request option is not set' do
            #puts handler.default_request_options
            expect(handler.default_request_options[:private_key_file]).to eql("blarg")
          end
        end
      end

      describe '#fetch_request_options' do
        it "should set :query and :body to request.querystring" do
          opts = handler.send(:fetch_request_options, req)
          expect(opts[:query]).to eql(req.querystring)
        end

        it "should set :path to request.path" do
          opts = handler.send(:fetch_request_options, req)
          expect(opts[:path]).to eql(req.path)
        end

        context "request.body_stream is a StringIO" do
          it "should set :body to request.body_stream" do
            opts = handler.send(:fetch_request_options, req)
            expect(opts[:body]).to eql("myStringIO")
          end
        end

        context "request.body_stream is an object that responds to :path" do
          let(:io_object) { EMFooIO.new }

          before(:each) do
            allow(req).to receive(:body_stream).and_return(io_object)
          end

          it "should set :file to object.path " do
            opts = handler.send(:fetch_request_options, req)
            expect(opts[:file]).to eql(io_object.path)
          end
        end
      end

      describe '#fetch_client_options' do
        it "should remove pool related options" do
          opts = handler.send(:fetch_client_options)

          expect(opts.has_key?(:size)).to eql(false)
          expect(opts.has_key?(:never_block)).to eql(false)
          expect(opts.has_key?(:blocking_timeout)).to eql(false)
        end

        context "when with_pool is true" do
          before(:each) do
            allow(handler).to receive(:with_pool?).and_return(true)
          end

          it "should set keepalive as true" do
            opts = handler.send(:fetch_client_options)

            expect(opts[:keepalive]).to eql(true)
          end
        end

        context "when with_pool is false" do
          before(:each) do
            allow(handler).to receive(:with_pool?).and_return(false)
          end

          it "should keepalive be false" do
            opts = handler.send(:fetch_client_options)

            expect(opts[:keepalive]).to be_falsey
          end
        end
      end
    end
  end
end
