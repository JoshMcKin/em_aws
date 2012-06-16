require 'spec_helper'
require 'aws'
describe AWS::Mutex do
  it "should be a fiber safe mutex" do
    AWS::Mutex.new.should be_kind_of(EM::Synchrony::Thread::Mutex)
  end
  
  it "should be a fiber mutex when called within AWS module" do
    AWS.module_eval <<-STR
    def self.mutex_new
      Mutex.new
    end
    STR

    AWS.mutex_new.should be_kind_of(EM::Synchrony::Thread::Mutex)
  end
  
  it "should not affect Mutex outside AWS" do
    Mutex.new.should be_kind_of(Mutex)
  end
end

describe AWS::Kernel,'#sleep' do
  it "should be a fiber safe sleep from with AWS module" do
    EM::Synchrony.stub(:sleep).and_return("fiber safe")
    AWS::Kernel.sleep(1).should eql("fiber safe")
  end
  
  it "should not affect normal Kernel.sleep " do
    EM::Synchrony.stub(:sleep).and_return("fiber safe")
    Kernel.sleep(1).should eql(1)
  end
  
  it "should be a fiber mutex when called within AWS module" do
    AWS.module_eval <<-STR
    def self.sleep(time)
      Kernel.sleep(time)
    end
    STR
    EM::Synchrony.stub(:sleep).and_return("fiber safe")
    AWS.sleep(0.01).should eql("fiber safe")
  end 
  
  it "should not interfer with other Kernel methods" do     
    lambda {AWS::Kernel.rand}.should_not raise_error
  end
end

