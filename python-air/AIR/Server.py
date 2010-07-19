"""
The AIR.Server registers named services with an AIR configured AMQP
server and listens for requests.

A request is a json hash with 4 expected items:
 msgID
 parameters
 returnKey
 deadline

"""

from AIR.AMQPServer import AMQPServer

import sys, traceback
from amqplib import client_0_8 as amqp
from amqplib.client_0_8 import AMQPChannelException, Timeout
try:
     import simplejson as json
except ImportError:
     import json
import uuid
import time

import pprint

class ServiceExists(Exception):
    pass

class Server(AMQPServer):
    """
    Establishes an AIR Server on an AMQP server.
    Services can register here and then be called.
    """

    def __init__(self, *args, **kwargs):
        """
        An AIR Server extends an AMQPServer helper object and takes
        the usual AMQP connectivity options.

        Requests will all arrive at one queue and will be dealt with
        serially for all services registered by this server instance.

        services may be shared or not.
        """
        # First allow the super to setup the AMQP connections
        super(Server, self).__init__(*args, **kwargs)

        # Create a hash to lookup our services
        self.lookup = {}

        # and a uuid that we'll use to create a queue to send all our
        # service requests to
        self.uuid = uuid.uuid1()

        # Assert the existence of AIR request exchange
        try:
            self.chan.exchange_declare(exchange="AIR-request", type="direct",
                                   durable=True,  auto_delete=False)
        except AMQPChannelException, e:
            try:
                print """
                      AIR-request exchange is misconfigured.
                      Attempting to delete it.  This will only work if
                      there are no clients or servers using the
                      exchange
                      """
                self.chan.exchange_delete(exchange="AIR-request")
                self.chan.exchange_declare(exchange="AIR-request", type="direct",
                                           durable=True,  auto_delete=False)
            except AMQPChannelException, e:
                # the channel was deleted.. need to recreate
                raise e

        # ... and the response exchange
        try:
            self.chan.exchange_declare(exchange="AIR-response", type="direct",
                                       durable=False,  auto_delete=False)
        except AMQPChannelException, e:
            try:
                print """
                      AIR-response exchange is misconfigured.
                      Attempting to delete it.  This will only work if
                      there are no clients or servers using the
                      exchange
                      """
                self.chan.exchange_delete(exchange="AIR-response", if_unused=True)
                self.chan.exchange_declare(exchange="AIR-response", type="direct",
                                           durable=False,  auto_delete=False)
            except AMQPChannelException, e:
                # the channel was deleted.. need to recreate
                raise e

        # Create a transient queue which this Server will receive all
        # incoming calls on for non-shared services
        self.q, _, _ = self.chan.queue_declare()

        # and set the callback 
        self.chan.basic_consume(queue=self.q, no_ack=False,
                                callback=self._callback)

    def run(self, timeout=None):
        """
        Currently an infinite loop waiting for messages on the AMQP channel.
        """
        try:
            while True:
                self.chan.wait(timeout=timeout)
        except Timeout:
            return

    def finish(self):
        "Closes channel and connection"
        self.chan.basic_cancel()
        self.chan.close()
        self.conn.close()

    def register(self, service_name, fn, shared=False):
        """
        Register a service name to call a given method.
        shared services may have multiple servers.
        This binds a routing key on the AIR exchange.
        """

        # TODO: Check for a legal service name?
        if service_name in self.lookup:
            raise ServiceExists()

        # Assert a service queue
        q, _, _ = self.chan.queue_declare(queue=service_name,
                                          durable=True,
                                          auto_delete=True,
                                          exclusive=not shared)

        # bind the queue using a routing key of our service name
        self.chan.queue_bind(queue=q, exchange="AIR-request",
                             routing_key=service_name)

        # and set a callback. We will ack when we know we can dispatch
        self.chan.basic_consume(queue=q, no_ack=True,
                                callback=self._callback)
 
        # Store the service handler
        self.lookup[service_name] = fn


    def unregister(self, service_name):
        """
        Un-register a service name.
        This removes a binding for a routing key on the AIR exchange.
        AMQP 0.8 doesn't support unbind
        """
        self.lookup.remove(service_name)
#        self.chan.queue_unbind(queue=uuid, exchange="AIR",
#                               routing_key=service_name)


    def _callback(self, msg):
        """
        The callback is passed an AMQP Message, parses it and calls
        the appropriate method.
        It then puts the method result into a reply and sends it.
        """
        # First use the routing key to get the service_name
#        print "message body: %s" % msg.body
        print "message props"
        for key, val in msg.properties.items():
            print '%s: %s' % (key, str(val))
        for key, val in msg.delivery_info.items():
            print '> %s: %s' % (key, str(val))

        try: # catch malformed msg
            rkey = msg.delivery_info['routing_key']
            if rkey in self.lookup:
                fn = self.lookup[rkey]
            else:
                raise Exception("Unknown service: %s" % rkey)

            # Acknowledge now we've found it
            msg.channel.basic_ack(msg.delivery_tag)

            h = json.loads(msg.body)

            # Don't bother if we've passed the deadline
            # Allow for a little drift
            if h['deadline'] and time.time() > h['deadline'] + 3:
                return

            args = h["args"]
            if not isinstance(args, list):
                args=[]

            kwargs = h["kwargs"]
            # Ensure kwargs are not unicode: http://bugs.python.org/issue4978
            if isinstance(kwargs, dict):
                kwargs = dict([(k.encode('ascii','ignore'), v) for k, v in kwargs.items()])
            else:
                kwargs={}

            # call the function
            r = fn(*args, **kwargs)

            # Don't bother to reply if we've passed the deadline
            # Allow for a little drift
            if h['deadline'] and time.time() > h['deadline'] + 3:
                return

            reply_body = {"msgID": h['msgID'],
                          "return": r
                          }
            reply = amqp.Message(json.dumps(reply_body), delivery_mode=2)

            # Send it back to the requestor
            self.chan.basic_publish(reply, exchange='AIR-response',
                                    routing_key=msg.properties["reply_to"])

        except KeyError: # malformed msg
            print "Exception whilst handling message:"
            pp = pprint.PrettyPrinter(indent=4)
            pp.pprint(h)
#            raise e
