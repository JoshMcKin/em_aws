require 'spec_helper'
require 'aws-sdk-v1'
require 'aws/core/http/em_http_handler'

describe AWS::DynamoDB do
  if ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']

    around(:each) do |example|
      EM.synchrony do
        example.run
        EM.stop
      end
    end

    it "should work" do
      begin
        AWS.config( :http_handler => AWS::Http::EMHttpHandler.new(:pool_size => 20))
        dynamo_db = AWS::DynamoDB.new
        dynamo_db.tables['mytable'].delete if dynamo_db.tables['mytable'].exists?
        
        # Create table
        dynamo_db.tables.create('mytable', 10, 5)
        table = dynamo_db.tables['mytable']

        sleep 1 while table.status == :creating

        expect(table).to be_exists
        # Write
        table.batch_put([
                          { :id => 'id1', :color => 'red' },
                          { :id => 'id2', :color => 'blue' },
                          { :id => 'id3', :color => 'green' },
        ])

        #Read
        items = %w(id1 id2 id3)
        expect(table.batch_get('id',items).to_a.collect{ |h| h['id']}.sort).to eql(['id1','id2','id3'])
      ensure
        table.delete if table && table.exists? #clean up
      end
    end
  end

end
