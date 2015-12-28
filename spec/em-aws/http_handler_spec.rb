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
require 'aws/core/http/em_http_handler'
module AWS::Core
  module Http
    class EMFooIO
      def path
        "/my_path/test.text"
      end
    end

    # A server for testing response,
    # borrowed from: http://www.igvita.com/2008/05/27/ruby-eventmachine-the-speed-demon/
    class AwsServer < EventMachine::Connection
      include EventMachine::HttpServer

      def process_http_request
        resp = EventMachine::DelegatedHttpResponse.new( self )
        resp.status = 200
        resp.content = "Hello World!"
        resp.send_response
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

    describe EM::AWS::HttpHandler do

      around(:each) do |example|
        EM.synchrony do
          example.run
          EM.stop
        end
      end

      let(:handler_opts) do
        {:verify_response_body_content_length => true}
      end

      let(:handler) { EM::AWS::HttpHandler.new(handler_opts) }

      let(:request) do
        double('aws-request',
               :http_method => 'POST',
               :endpoint => 'https://host.com',
               :uri => '/path?querystring',
               :path => '/path',
               :host => 'host.com',
               :port => 443,
               :querystring => 'querystring',
               :body_stream => StringIO.new('body'),
               :body => 'body',
               :use_ssl? => true,
               :ssl_verify_peer? => true,
               :ssl_ca_file => '/ssl/ca',
               :ssl_ca_path => nil,
               :read_timeout => 60,
               :continue_timeout => 1,
               :headers => { 'foo' => 'bar' })
      end

      let(:response) { Response.new }

      let(:read_block) { }

      let(:handle!) { handler.handle(request, response, &read_block) }

      let(:http) { double('http-session').as_null_object }

      let(:http_response) {
        double = double('http response',
                        :code => '200',
                        :response => 'resp-body',
                        :to_hash => { 'header-name' => ['header-value'] })
        allow(double).to receive(:stream) do |&block|
          block ? block.call('resp-body') : 'resp-body'
        end
        double
      }

      before(:each) do
        allow(http).to receive(:request).and_yield(http_response)
      end

      it 'should be accessible from AWS as well as AWS::Core' do
        expect(AWS::Http::EMHttpHandler.new).to be_an(EM::AWS::HttpHandler)
      end

      describe '#handle' do
        context 'exceptions' do
          it 'should rescue Timeout::Error' do
            allow(handler).to receive(:fetch_response).and_raise(Timeout::Error)

            expect {
              handle!
            }.to_not raise_error
          end

          it 'should rescue Errno::ETIMEDOUT' do
            allow(handler).to receive(:fetch_response).and_raise(Errno::ETIMEDOUT)

            expect {
              handle!
            }.to_not raise_error
          end

          it 'should indicate that there was a network_error' do
            allow(handler).to receive(:fetch_response).and_raise(Errno::ETIMEDOUT)

            handle!

            expect(response).to be_network_error
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
          opts = handler.send(:fetch_request_options, request)
          expect(opts[:query]).to eql(request.querystring)
        end

        it "should set :path to request.path" do
          opts = handler.send(:fetch_request_options, request)
          expect(opts[:path]).to eql(request.path)
        end

        context "request.body_stream is a StringIO" do
          it "should set :body to request.body_stream" do
            opts = handler.send(:fetch_request_options, request)
            expect(opts[:body]).to eql("body")
          end
        end

        context "request.body_stream is an object that responds to :path" do
          let(:io_object) { EMFooIO.new }

          before(:each) do
            allow(request).to receive(:body_stream).and_return(io_object)
          end

          it "should set :file to object.path " do
            opts = handler.send(:fetch_request_options, request)
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

        context "when keepalive is not set" do

          it "should be true" do
            opts = handler.send(:fetch_client_options)

            expect(opts[:keepalive]).to eql(true)
          end
        end

        context "when keepalive is false" do

          it "should be false" do
            handler.default_options[:keepalive] = false
            opts = handler.send(:fetch_client_options)

            expect(opts[:keepalive]).to eql(false)
          end
        end
      end

      context 'content-length checking' do

        let(:http_response) {
          double = double('http-response',
                          :code => '200',
                          :response => 'resp-body',
                          :to_hash => { 'content-length' => ["10000"] })
          allow(double).to receive(:stream) do |&block|
            block ? block.call('resp-body') : 'resp-body'
          end
          double
        }

        it 'should raise if content-length does not match' do
          server = nil
          EventMachine::run do
            server = EventMachine::start_server '127.0.0.1', '8081', AwsServer
          end
          allow(handler).to receive(:fetch_url).and_return("http://127.0.0.1:8081")
          allow(handler).to receive(:determine_expected_content_length).and_return(1)
          handle!
          expect(response.network_error).to be_a_kind_of(NetHttpHandler::TruncatedBodyError)
          EventMachine.stop_server(server)
        end

        context 'can turn off length checking' do
          let(:handler_opts) {{:verify_response_body_content_length => false}}

          let(:handler) { described_class.new(handler_opts) }

          it 'should not raise if length does not match but check is off' do
            expect(response.network_error).to be_nil
          end

        end
      end

      context 'slow requests' do
        context 'with inactivity_timeout = 0' do
          it "should not timeout" do
            server = nil
            # turn on our test server
            EventMachine::run do
              server =  EventMachine::start_server '127.0.0.1', '8081', SlowServer
            end

            allow(handler).to receive(:fetch_url).and_return("http://127.0.0.1:8081")

            handle!

            expect(response.network_error).to be_nil

            EventMachine.stop_server(server)
          end
        end
        context 'with inactivity_timeout > 0' do
          it "should timeout" do
            server = nil
            # turn on our test server
            EventMachine::run do
              server = EventMachine::start_server '127.0.0.1', '8081', SlowServer
            end

            allow(handler).to receive(:fetch_url).and_return("http://127.0.0.1:8081")
            handler.client_options[:inactivity_timeout] = 0.01
            allow(handler).to receive(:connect_timeout).and_return(1) #just to speed up the test

            handle!

            expect(response.network_error).to be_a(Timeout::Error)

            EventMachine.stop_server(server)
          end
        end
      end
    end
  end
end
