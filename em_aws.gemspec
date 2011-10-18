# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em_aws/version"
require 'syck'
YAML::ENGINE.yamler= 'syck' # fix some Heroku Syck weirdness
Gem::Specification.new do |s|
  s.name        = "em_aws"
  s.version     = EmAws::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joshua Mckinney"]
  s.email       = ["joshmckin@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Adds EM-Synchrony support to AWS-SDK gem}
  s.description = %q{Adds EM-Synchrony support to AWS-SDK gem}

  s.rubyforge_project = "em_aws"
  
  s.add_runtime_dependency "aws-sdk"
  s.add_runtime_dependency "em-synchrony"
  s.add_runtime_dependency "em-http-request"
  s.add_development_dependency "rspec" , '2.6.0'
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
