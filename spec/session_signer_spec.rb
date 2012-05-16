require 'spec_helper'

describe AWS::Core::SessionSigner do
  context '@create_mutex' do
    it "should be a fiber safe mutex" do
      AWS::Core::SessionSigner.instance_variable_get(:@create_mutex).should be_kind_of(EM::Synchrony::Thread::Mutex)
    end
  end
end

