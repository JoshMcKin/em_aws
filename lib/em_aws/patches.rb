require 'em-synchrony'
require 'em-synchrony/thread'

Mutex.class_eval do
  class << self
    alias :mutex_new :new
    def new    
      return EM::Synchrony::Thread::Mutex.new   if defined?(EM) && EM.reactor_running?
      mutex_new
    end
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