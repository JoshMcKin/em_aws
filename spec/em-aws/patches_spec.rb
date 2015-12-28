require 'spec_helper'
describe Mutex do
  around(:each) do |example|
    EM.synchrony do
      example.run
      EM.stop
    end
  end

  it "should be a fiber safe mutex" do
    expect(AWS::Mutex.new).to be_kind_of(EM::Synchrony::Thread::Mutex)
  end

  it "should be a fiber safe mutex" do
    expect(AWS.mutex.new).to be_kind_of(EM::Synchrony::Thread::Mutex)
  end

  it "should not affect Mutex outside AWS" do
    expect(Mutex.new).to be_kind_of(Mutex)
  end
end

describe Kernel, '#sleep' do

  it "should be a fiber safe sleep from with AWS module" do
    EM.synchrony do
      EM::Synchrony.stub(:sleep).and_return("fiber safe")
      expect(Kernel.sleep(1)).to eql("fiber safe")
      EM.stop
    end
  end

  it "should not affect normal Kernel.sleep if not in EM" do
    expect(Kernel.sleep(1)).to eql(1)
  end
end
