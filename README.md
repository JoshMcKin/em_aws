# em_aws
An EM-Synchrony handler for Ruby [AWS-SDK](https://github.com/JoshMcKin/aws-sdk-for-ruby)

This code has be submitted to AWS-SKD see: [pull request](https://github.com/amazonwebservices/aws-sdk-for-ruby/pull/14). 
Until approval (or if it is declined) I created this gem.

## Installation

em_aws is available through [Rubygems](https://rubygems.org/gems/em_aws) and can be installed via:

    $ gem install em_aws

## Rails 3 setup (no rails 2 sorry)
Setup [AWS-SKD](https://github.com/amazonwebservices/aws-sdk-for-ruby/blob/master/README.rdoc) as you would normally.

Assuming you've already setup async-rails, add em_aws to you gemfile:
    
    gem 'em_aws'

Then run:
    
    bundle install

In your environments files add:

    require 'aws-sdk'
    require 'aws/core/http/em_http_handler'
    AWS.config(
      :http_handler => AWS::Http::EMHttpHandler.new(
      :proxy => {:host => "http://myproxy.com", :port => 80}
       ));

Your done. 

All requests to AWS will use EM-Synchrony's implementation of em-http-request for non-block HTTP request and fiber management.

## Connection Pooling (keep-alive)
To enable connection pooling set the :pool_size to anything greater than 0. By default :inactivity_timeout is set
to 0 which will leave the connection open for as long as the client allows.
    
    require 'aws-sdk'
    require 'aws/core/http/em_http_handler'
    AWS.config(
      :http_handler => AWS::Http::EMHttpHandler.new(
      :pool_size => 20,
      :inactivity_timeout => 30, # number of seconds to timeout stale connections in the pool
      :proxy => {:host => "http://myproxy.com",:port => 80})
    )

VERY VERY subjective benchmarks...but its still a pretty nice result.

    EM.synchrony do 
      Benchmark.bm do |b|
        b.report("default") do
          100.times { 
            MyTestSimpleDB.where('id = ?',Random.new.rand(100000000...999999999)).first
          }
        end
        b.report("default") do
          100.times { 
            MyTestSimpleDB.where('id = ?',Random.new.rand(100000000...999999999)).first
          }
        end
      end
      EM.stop
    end


    # :pool_size => 0 (the default value)
                user     system      total        real
    default  0.980000   0.170000   1.150000 ( 24.760014)
    default  0.980000   0.160000   1.140000 ( 27.072073)


    # :pool_size => 5
                user     system      total        real
    pool     0.690000   0.050000   0.740000 (  9.745807)
    pool     0.620000   0.040000   0.660000 (  7.658251)

## References

  [aws-sdk](https://github.com/amazonwebservices/aws-sdk-for-ruby)

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
Code based on HTTParty Hander in [aws-sdk](https://github.com/amazonwebservices/aws-sdk-for-ruby/blob/master/README.rdoc)
