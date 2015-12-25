require 'spec_helper'
require 'aws-sdk-v1'
require 'aws/core/http/em_http_handler'

describe AWS::S3 do
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
        s3 = AWS::S3.new

        # Create bucket
        s3.buckets.create('em_test_bucket')
        bucket = s3.buckets['em_test_bucket']
        expect(bucket).to be_exists

        # Write
        filler = '1'*1048576
        bucket.objects['test'].write(filler)

        # Streaming/Read
        streamed = ""
        bucket.objects["test"].read do |chunk|
          streamed << chunk
        end
        expect(streamed).to eql(filler)
      ensure
        bucket.delete! if bucket #clean up
      end
    end
  end

end
