# EmAws
An EM-Synchrony handler for Ruby [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby)

## Installation

em_aws is available through [Rubygems](https://rubygems.org/gems/em_aws) and can be installed via:

    $ gem install em_aws

## Rails 3 setup (no rails 2 sorry)
Setup [AWS-SDK-Ruby](https://github.com/aws/aws-sdk-ruby/blob/master/README.rdoc) as you would normally.

Assuming you've already setup async-rails, add em_aws to you gemfile:
    
    gem 'em_aws'

Then run:
    
    bundle install

In your environments files add:

    require 'aws-sdk'
    require 'aws/core/http/em_http_handler'
    AWS.eager_autoload! # AWS lazyloading is not threadsafe
    AWS.config(
      :http_handler => AWS::Http::EMHttpHandler.new(
      :proxy => {:host => "http://myproxy.com", :port => 80}))
      :pool_size => 0 # by default connection pooling is off
      :async => false # if set to true all requests for this client will be asynchronous

Your done. 

All requests to AWS will use EM-Synchrony's implementation of em-http-request for non-block HTTP requests and fiber management.

## Connection Pooling (keep-alive)
To enable connection pooling set the :pool_size to anything greater than 0. By default :inactivity_timeout is set
to 0 which will leave the connection open for as long as the client allows. Connects
are created lazy, so pools grow until they meet the set pool size.
    
    require 'aws-sdk'
    require 'aws/core/http/em_http_handler'
    AWS.config(
      :http_handler => AWS::Http::EMHttpHandler.new({
        :pool_size => 20,
        :inactivity_timeout => 0, # number of seconds to timeout stale connections in the pool,
        :never_block => true, # if we run out of connections, create a new one
        :proxy => {:host => "http://myproxy.com",:port => 80})
    )

## Streaming
Requires [AWS-SKD-Ruby >= 1.6.3] (http://aws.amazon.com/releasenotes/Ruby/5728376747252106)
    EM.synchrony do
      s3 = AWS::S3.new 
      file = File.open("path_to_file")
      s3.buckets['bucket_name'].objects["foo.txt"].write(file)
      EM.stop
    end

## Asynchronous Requests
Requests can be set to perform asynchronously, returning nil initially and performing
the actions in the background. If the request option :async are set to true that only
that request request will handled asynchronously. If the client option :async all requests will 
be handled asynchronously.

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
