
# The AIR.Client calls services on an AIR configured AMQP server and
# listens for replies.
# 
# A request is a json hash with 4 expected items:
#  msgID
#  parameters
#  returnKey
#  deadline
# 
# 
# 
require 'mq'
require 'yajl'
require 'rufus/json'
#import sys, traceback
#from amqplib import client_0_8 as amqp
#from amqplib.client_0_8 import Timeout
#import simplejson as json
#import time


module AIR

  class AIRServiceExists < StandardError
  end

  class Timeout < StandardError
  end

  class AIRCrossTalk < StandardError
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
  end

  class Client

    # Establishes an AIR Client against an AMQP server.
    # Once created services can be accessed via call()
    def initialize( options )

      AIR.start!({ 
                    :host => "localhost",
                    :user => "air",
                    :pass => "air",
                    :vhost => "AIR"
                  }.merge( options )) do
        @mq = MQ.new

        # Assert the existence of AIR request exchange
        @req_ex = @mq.direct( "AIR-request", :durable => true,  :auto_delete => false )
        # Assert the existence of AIR response exchange
        @resp_ex = @mq.direct( "AIR-response", :durable => false, :auto_delete => false)
        # Create a transient queue for responses
        @q = @mq.queue( "air-reply#{::Kernel.rand(999_999_999_999)}", :auto_delete => true )

        # bind our queue using a routing key of our queue name
        @q.bind( @resp_ex, :key => @q.name)
        
        @q.subscribe(:ack => true, :timeout => @timeout) do |header, msg|
          # The callback is passed an AMQP Message, parses it and calls
          # the appropriate method.
          @response = msg
          @reply = true
          end
      end
    end

    def finish
      # Closes channel and connection
      @chan.close()
      @conn.close()
    end

    def call ( service_name, opts)
      # Call a service with the given *args and **kwargs
      # Raises a Timeout if the timeout is exceeded.
      #
      # This binds a routing key on the AIR exchange.

      if opts[:timeout]
        @deadline = Time.now.tv_sec + opts[:timeout]
        @timeout = opts[:timeout]
      else
        @deadline = nil
        @timeout = nil
      end

      opts.delete :timeout

      args = opts.has_key? :args ? opts[:args] : nil
      opts.delete :args

      @msgID = "uuid-#{::Kernel.rand(999_999_999_999)}"
      msg = Rufus::Json.encode({
                         "msgID" => @msgID,
                         "args" => args,
                         "kwargs" => opts,
                         "deadline" => @deadline,
                       })
      

      # Publish the message.
      # FIXME: Need to check to see how the mandatory and immediate work?
      @req_ex.publish(msg, :key => service_name,
                      :reply_to => @q.name,
                      :immediate => false,
                      :mandatory => false )
#                      :immediate => true,
#                      :mandatory => true )

      @reply = false
      @response = false
      # Waits for reply messages on the AMQP channel.
      # Raises a Timeout if the timeout is exceeded.
      catch :timeout do
        while not @reply
          sleep 0.1 # FIXME
          if @deadline and @deadline < Time.now.tv_sec
            throw :timeout
          end
        end
      end

      if @response
        h = Rufus::Json.decode(@response)
        if h['msgID'] != @msgID
          raise AIRCrossTalk
        end
        return h['return']
      else
        raise Timeout
      end
    end
  end
end

