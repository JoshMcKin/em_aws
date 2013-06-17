require 'spec_helper'
require 'aws'
describe Mutex do
  it "should be a fiber safe mutex" do
    EM.synchrony do
      AWS::Mutex.new.should be_kind_of(EM::Synchrony::Thread::Mutex)
      EM.stop
    end
  end

  it "should be a fiber safe mutex" do
    EM.synchrony do
      AWS.mutex.new.should be_kind_of(EM::Synchrony::Thread::Mutex)
      EM.stop
    end
  end

  it "should not affect Mutex outside AWS" do
    Mutex.new.should be_kind_of(Mutex)
  end
end

describe Kernel, '#sleep' do
  it "should be a fiber safe sleep from with AWS module" do
    EM.synchrony do
      EM::Synchrony.stub(:sleep).and_return("fiber safe")
      Kernel.sleep(1).should eql("fiber safe")
      EM.stop
    end
  end

  it "should not affect normal Kernel.sleep if not in EM" do
    Kernel.sleep(1).should eql(1)
  end
end
