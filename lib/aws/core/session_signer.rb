require 'em-synchrony/thread'
module AWS
  module Core
    class SessionSigner
      @create_mutex = EM::Synchrony::Thread::Mutex.new
    end
  end
end