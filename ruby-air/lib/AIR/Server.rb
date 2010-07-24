# The AIR.Client calls services on an AIR configured AMQP server and
# listens for replies.
# 
# A request is a json hash with 4 expected items:
#  msgID
#  parameters
#  returnKey
#  deadline
require 'mq'
require 'yajl'
require 'rufus/json'
require 'AIR/common'

module AIR
  # An AIR Server extends an AMQPServer helper object and takes
  # the usual AMQP connectivity options.
  #
  # Requests will all arrive at one queue and will be dealt with
  # serially for all services registered by this server instance.
  #
  # services may be shared or not.
  class Server

    # Establishes an AIR Server on an AMQP server.
    # Services can register here and then be called.
    def initialize( options )

      AIR.start!({ 
                    :host => "localhost",
                    :user => "air",
                    :pass => "air",
                    :vhost => "AIR"
                  }.merge( options )) do
        @mq = MQ.new

        @lookup = {}

        # Assert the existence of AIR request exchange
        @req_ex = @mq.direct( "AIR-request", :durable => true,  :auto_delete => false )
        # Assert the existence of AIR response exchange
        @resp_ex = @mq.direct( "AIR-response", :durable => false, :auto_delete => false)
        # Create a transient queue for responses
        @q = @mq.queue( "air-reply#{::Kernel.rand(999_999_999_999)}", :auto_delete => true )

        @q.subscribe(:ack => true, :timeout => @timeout) do |header, msg|
          # The callback is passed an AMQP Message, parses it and calls
          # the appropriate method.
          _callback(msg, headers)
        end
      end
    end

    # Register a service name to call a given method.
    # shared services may have multiple servers.
    # This binds a routing key on the AIR exchange.
    def register(service_name, fn, shared=false)
      # bind our queue using a routing key of our queue name
      if @lookup.has_key? service_name
        raise ServiceExists
      end
      # Assert a service queue
      q = @mq.queue(service_name,
                    :durable => true,
                    :auto_delete => true,
                    :exclusive => ! shared)
      
      # bind the queue using a routing key of our service name
      q.bind( @req_ex, :key => service_name)

      # and set a callback. We will ack when we know we can dispatch
      q.subscribe(:ack => true, :ack => false)  do |header, msg|
        # The callback is passed an AMQP Message, parses it and calls
        # the appropriate method.
        _callback(msg, header)
      end
 
      # Store the service handler
      @lookup[service_name] = fn
    end

    def unregister(service_name)
      # Un-register a service name.
      # This removes a binding for a routing key on the AIR exchange.
      # AMQP 0.8 doesn't support unbind

      @lookup.remove(service_name)
      # @q.unbind(exchange="AIR",
      #           routing_key=service_name)
    end

    # The callback is passed an AMQP Message, parses it and calls
    # the appropriate method.
    # It then puts the method result into a reply and sends it.
    def _callback(msg, header)
      # First use the routing key to get the service_name
      #puts "message header"
      #header.properties.each do |key, val| 
      #  puts "#{key} => #{val}"
      #end

      rkey = header.properties[:routing_key]
      if @lookup.has_key? rkey
        fn = @lookup[rkey]
      else
        raise UnknownService, rkey
      end
      # Acknowledge now we've found it
#      msg.channel.basic_ack(msg.delivery_tag)

      h = Rufus::Json.decode(msg)

      # Don't bother if we've passed the deadline
      # Allow for a little drift
      if h['deadline'] and time.time() > h['deadline'] + 3:
          return
      end
      args = h["args"]
      if args.nil?
        args=[]
      end
      kwargs = h["kwargs"]
      # Ensure kwargs are not unicode: http://bugs.python.org/issue4978
      if kwargs.nil?
        kwargs={}
      end
      # call the function
      r = fn.call(args, kwargs)

      # Don't bother to reply if we've passed the deadline
      # Allow for a little drift
      if h['deadline'] and time.time() > h['deadline'] + 3
        return
      end
      reply_body = {
        "msgID" => h['msgID'],
        "return" => r
      }
      # Send it back to the requestor
      @resp_ex.publish(Rufus::Json.encode(reply_body), 
                       :key => header.properties[:reply_to],
                       :delivery_mode => 2,
                       :immediate => false,
                       :mandatory => false )
    end
    # Simulate a run loop
    def run
      AIR.wait!
    end
  end

end
