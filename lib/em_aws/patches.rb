require 'em-synchrony'
require 'em-synchrony/thread'

# Scope the Mutex constant override to within AWS. May cause constant override
# warnings in newer ruby versions
module AWS
  Mutex = EM::Synchrony::Thread::Mutex
  
  # easy access for testing
  def self.mutex
    Mutex
  end
end

Kernel.class_eval do
  class << self
    alias :kernel_sleep :sleep
    def sleep(count)      
      return EM::Synchrony.sleep(count) if defined?(EM) && EM.reactor_running?
      kernel_sleep(count)
    end
  end
end