require 'spec_helper'

describe AWS::Core::SessionSigner do
  context '@create_mutex' do
    it "should be a fiber safe mutex" do
      AWS::Core::SessionSigner.instance_variable_get(:@create_mutex).should be_kind_of(EM::Synchrony::Thread::Mutex)
    end
  end

  context '@session_mutex' do
    let(:config) { double("config").as_null_object }
    it "should be a fiber safe mutex" do
      session_signer = AWS::Core::SessionSigner.new(config)
      session_signer.instance_variable_get(:@session_mutex).should be_kind_of(EM::Synchrony::Thread::Mutex)
    end
  end
end

describe AWS::S3::MultipartUpload do
  context '@increment_mutex' do
    it "should be a fiber safe mutex" do
      a = AWS::S3::MultipartUpload.new(:foo,1)
      a.instance_variable_get(:@increment_mutex).should be_kind_of(EM::Synchrony::Thread::Mutex)
    end
  end
  context '@completed_mutex' do
    it "should be a fiber safe mutex" do
      a = AWS::S3::MultipartUpload.new(:foo,1)
      a.instance_variable_get(:@completed_mutex).should be_kind_of(EM::Synchrony::Thread::Mutex)
    end
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
  
  it "should not interfer with other Kernel methods" do     
   lambda {AWS::Kernel.rand}.should_not raise_error
  end
end

