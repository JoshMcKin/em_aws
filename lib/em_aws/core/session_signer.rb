require 'em-synchrony/thread'
module AWS
  module Core
    class SessionSigner
      @create_mutex = EM::Synchrony::Thread::Mutex.new

      # Monkey patch to use EM::Synchrony::Thread::Mutex instead of ::Mutex
      def initialize config
        @config = config
        @session_mutex = EM::Synchrony::Thread::Mutex.new
      end
    end
  end
end
