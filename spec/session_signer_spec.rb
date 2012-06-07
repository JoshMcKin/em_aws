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
