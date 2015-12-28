# EM::AWS
An EM-Synchrony handler for Ruby [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby)
## Installation

EM::AWS is available through [Rubygems](https://rubygems.org/gems/em_aws) and can be installed via:

    $ gem install em_aws

### Requirements

  * EmAws 0.4.x requires [AWS-SDK-v1](https://github.com/aws/aws-sdk-ruby/blob/aws-sdk-v1)

## Rails 3 setup

Setup [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby/blob/aws-sdk-v1/README.md) as you would normally.

Assuming you've already setup async-rails, add em_aws to your gemfile:
    
    gem 'em_aws'

Then run:
    
    bundle install

Add the following to your aws.rb initializer:

    require 'em-aws'
    AWS.config( :http_handler => EM::AWS::HttpHandler.new ) 

You are done. 

All requests to AWS will use EM-Synchrony's implementation of em-http-request for non-block HTTP requests and fiber management. See [EM-HTTP-Request](https://github.com/igrigorik/em-http-request/wiki/Issuing-Requests#available-connection--request-parameters) for all client options

## Connection Pooling (w/keep-alive)

We use [EM-HotTub](https://github.com/JoshMcKin/em-hot_tub) to manage connection pooling. To enable connection pooling set the :pool_size to anything greater than 1, default is 5. By default :inactivity_timeout is set to 0 which will leave the connection open for as long as the AWS allows. Connections are created lazy, so pools grows to meet concurrency. If we need to limit our total number of connections we can set :max_size. HotTub will reap connections down to :pool_size when load dies.
    
    require 'em-aws'
    AWS.config(
      :http_handler => EM::AWS::HttpHandler.new({
        :pool_size => 20, # default is 5, setting to 1 disables pool
    )

## Streaming
Streaming from disk,You can pass an IO object in the :data option instead but the object must 
respond to :path. We cannot stream from memory at this time.

    EM.synchrony do
      s3 = AWS::S3.new 
      s3.buckets['bucket_name'].objects["foo.txt"].write(:file => "path_to_file")
      EM.stop
    end

    # Stream from AWS
    EM.synchrony do
      s3 = AWS::S3.new 
      s3.buckets['bucket_name'].objects["foo.txt"].read do |chunk|
        puts chunk
      end
      EM.stop
    end

## Asynchronous Requests
Requests can be set to perform asynchronously, returning nil initially and performing
the actions in the background. If the request option :async are set to true, only
that request will be handled asynchronously. If the client option :async is set to true,
all requests will be handled asynchronously.

    EM.synchrony do
      s3 = AWS::S3.new
      s3.buckets['bucket-name'].objects["foo"].write('test', :async => true) # => nil
      EM::Synchrony.sleep(2) # Let the pending fibers run
      s3.buckets['bucket-name'].objects["foo"].read # => # 'test'
      s3.buckets['bucket-name'].objects["foo"].delete(:async => true) # => nil
      EM::Synchrony.sleep(2) # Let the pending fibers run
      EM.stop
    end

## References

  [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby)

  [Async-Rails](https://github.com/igrigorik/async-rails)

  [Phat](http://www.mikeperham.com/2010/04/03/introducing-phat-an-asynchronous-rails-app/)

## Contributing to em_aws
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Thanks

Code based on HTTP Handers in [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby/blob/master/README.rdoc)

## License

EmAws [license](https://github.com/JoshMcKin/em_aws/blob/master/LICENSE.txt)
AWS-SDK-Ruby [license](https://github.com/aws/aws-sdk-for-ruby/blob/master/LICENSE.txt)
