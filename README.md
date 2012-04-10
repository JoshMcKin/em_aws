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
      :pool_size => 5,
      :proxy => {:host => "http://myproxy.com", :port => 80}
       ))

Your done. 

All requests to AWS will use EM-Synchrony's implementation of em-http-request for non-block HTTP request and fiber management.

## Connection Pools
v0.1+ implement connections EventMachine::Synchrony::ConnectionPool. The default pool_size is 5 but it can be
increased by in the AWS.config options. Connection pools were problematic for S3 calls that required the :path option for
em-http-request and would return AWS::S3::SignatureDoesNotMatch errors; so for now S3 calls with paths do not make use of the connection pools.

## Heroku Gotcha
When deploying to Heroku, if you get "NameError: uninitialized constant Syck::Syck", you need to vendorize em_aws
    
From your apps root directory run:

    gem unpack em_aws --target vendor/gems

Update you gemfile:

    gem 'em_aws', :path => "vendor/gems/em_aws-0.0.3"

Finally, run bundler and make sure you check-in your new Gemfile.lock. 
I'm pretty sure the Syck error is do to an outdated version of rubygems and bundler on Heroku, but as of yet have not been able to reproduce it locally.

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
