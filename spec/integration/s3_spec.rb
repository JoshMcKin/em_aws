require 'spec_helper'

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
        AWS.config( :http_handler => EM::AWS::HttpHandler.new )
        s3 = AWS::S3.new

        # Create bucket
        s3.buckets.create('em_test_bucket')
        bucket = s3.buckets['em_test_bucket']
        expect(bucket).to be_exists

        # Concurrent writes
        filler = '1'*1048576

        fibers = []
        5.times.each do |i|
          fiber = Fiber.new do
            bucket.objects["test#{i}"].write(filler)
          end
          fiber.resume
          fibers << fiber
        end

        # Wait until work is done
        while fibers.detect(&:alive?)
          EM::Synchrony.sleep(0.01)       
        end

        # Streaming/Read
        streamed = []
        bucket.objects["test1"].read do |chunk|
          streamed << chunk
        end
        expect(streamed.length).to be > 1 # make sure streaming took place
        expect(streamed.join).to eql(filler)
      ensure
        bucket.delete! if bucket # clean up
      end
    end
  end

end
