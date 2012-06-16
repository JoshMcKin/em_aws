require 'em-synchrony'
require 'em-synchrony/thread'
module AWS
  # Use EM::Synchrony.sleep for all Kernel.sleep in AWS
  DupKernel = Kernel
  
  class PatchKernel
    class << self
      def sleep(count)
        EM::Synchrony.sleep(count)
      end
      def method_missing(method,*args,&block)
        DupKernel.send(method, *args, &block)
      end
    end
  end
  
  Kernel = PatchKernel
  
  # Use a fiber safe mutex for Mutex in AWS
  Mutex = EM::Synchrony::Thread::Mutex  
end