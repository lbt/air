require 'mq'
require 'yajl'
require 'rufus/json'

module AIR
  class ServiceExists < StandardError
  end
  class UnknownService < StandardError
  end

  class Timeout < StandardError
  end

  class CrossTalk < StandardError
  end

  class << self
    # copied from RuoteAMQP
    # Ensure the AMQP connection is started
    def start!(opts)
      return if started?

      mutex = Mutex.new
      cv = ConditionVariable.new

      Thread.main[:air_amqp_connection] = Thread.new do
        Thread.abort_on_exception = true
        AMQP.start(opts) {
          started!
          cv.signal
        }
      end

      mutex.synchronize { cv.wait(mutex) }

      MQ.prefetch(1)

      yield if block_given?
    end
    # Check whether the AMQP connection is started
    def started?
      Thread.main[:air_amqp_started] == true
    end

    def started! #:nodoc:
      Thread.main[:air_amqp_started] = true
    end

    # Close down the AMQP connections
    def stop!
      return unless started?

      AMQP.stop
      Thread.main[:air_amqp_connection].join
      Thread.main[:air_amqp_started] = false
    end

    # wait for the server to finish.  This won't happen unless there's
    # a mechanism to call stop!
    def wait!
      return unless started?
      Thread.main[:air_amqp_connection].join
      Thread.main[:air_amqp_started] = false
    end
  end
end
