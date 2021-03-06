# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-aws/version"

Gem::Specification.new do |s|
  s.name        = "em_aws"
  s.version     = EventMachine::AWS::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joshua Mckinney"]
  s.email       = ["joshmckin@gmail.com"]
  s.homepage    = "https://github.com/JoshMcKin/em_aws"
  s.license     = "MIT"
  s.summary     = %q{Adds EM-Synchrony support to AWS-SDK gem}
  s.description = %q{An em-http-request handler for the aws-sdk for Fiber based asynchronous ruby application using EM-Synchrony}

  s.rubyforge_project = "em_aws"
  
  s.add_runtime_dependency "aws-sdk-v1"
  s.add_runtime_dependency "em-http-request"
  s.add_runtime_dependency "em-synchrony"
  s.add_runtime_dependency "em-hot_tub", "~> 1.1.0"

  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-autotest"
  s.add_development_dependency "autotest"
  s.add_development_dependency "rake" 
  s.add_development_dependency "eventmachine_httpserver"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
