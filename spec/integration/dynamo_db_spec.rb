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
        dynamo_db.tables.create('mytable', 10, 5) unless dynamo_db.tables['mytable'].exists?
        table = dynamo_db.tables['mytable']

        sleep 1 while table.status == :creating

        expect(table).to be_exists

        # Concurrent writes
        fibers = []
        5.times.each do |i|
          fiber = Fiber.new do
            table.batch_put([{ :id => "id#{i}"}])
          end
          fiber.resume
          fibers << fiber
        end

        # Wait until work is done
        while fibers.detect(&:alive?)
          EM::Synchrony.sleep(0.01)       
        end

        # Read our results
        items = %w(id0 id1 id2 id3 id4)
        expect(table.batch_get('id',items).to_a.collect{ |h| h['id']}.sort).to eql(['id0','id1','id2','id3','id4'])
      ensure
        table.delete if table && table.status != :deleting && table.exists? #clean up
      end
    end
  end

end
