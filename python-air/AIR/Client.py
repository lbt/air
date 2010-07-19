"""
The AIR.Client calls services on an AIR configured AMQP server and
listens for replies.

A request is a json hash with 4 expected items:
 msgID
 parameters
 returnKey
 deadline

"""

from AIR.AMQPServer import AMQPServer

# Consider immediate and mandatory flags

import sys, traceback
from amqplib import client_0_8 as amqp
from amqplib.client_0_8 import Timeout
try:
     import simplejson as json
except ImportError:
     import json

import uuid

import time

class AIRServiceExists(Exception):
    pass
class AIRCrossTalk(Exception):
    pass

class Client(AMQPServer):
    """
    """

    def __init__(self, *args, **kwargs):
        """
        Establishes an AIR Client against an AMQP server.
        Once created services can be accessed via call()
        """
        # First allow the super to setup the AMQP connections
        super(Client, self).__init__(*args, **kwargs)

        # Create a transient queue for responses
        self.q, _, _ = self.chan.queue_declare(auto_delete=True)

        # Assert the existence of AIR request exchange
        self.chan.exchange_declare(exchange="AIR-request", type="direct",
                                   durable=True,  auto_delete=False)
        # Assert the existence of AIR response exchange
        self.chan.exchange_declare(exchange="AIR-response", type="direct",
                                   durable=False, auto_delete=False)

        # bind our queue using a routing key of our queue name
        self.chan.queue_bind(queue=self.q, exchange="AIR-response",
                             routing_key=self.q)
        
        # and set the callback handler for responses
        self.chan.basic_consume(queue=self.q, no_ack=True,
                                consumer_tag="reply_recvd",
                                callback=self._callback)


    def run(self):
        """
        Waits for reply messages on the AMQP channel.
        Raises a Timeout if the timeout is exceeded.
        """
        while not self.reply:
            self.chan.wait(timeout=self.timeout)

    def finish(self):
        "Closes channel and connection"
        self.chan.close()
        self.conn.close()

    def call(self, service_name, timeout=None, *args, **kwargs):
        """
        Call a service with the given *args and **kwargs
        Raises a Timeout if the timeout is exceeded.
       
        This binds a routing key on the AIR exchange.
        """

        if timeout:
            self.deadline = time.time() + timeout
            self.timeout = timeout
        else:
            self.deadline = None
            self.timeout = None

        self.msgID = uuid.uuid1()
        msg = amqp.Message(json.dumps({
                    "msgID": self.msgID.urn,
                    "args":args,
                    "kwargs":kwargs,
                    "deadline":self.deadline,
                    }))
                     
        # delivery_mode=2 is persistent
        msg.properties["delivery_mode"] = 2 
        msg.properties["reply_to"] = self.q

        # Publish the message.
        # FIXME: Need to check to see if the mandator and immediate work?
        self.chan.basic_publish(msg, exchange='AIR-request',
                                routing_key=service_name,
                                immediate=True,
                                mandatory=True
                                )
        self.reply = False
        self.run() # Wait for a reply
        if self.response:
            h = json.loads(self.response.body)
            if h['msgID'] != self.msgID.urn:
                raise AIRCrossTalk
            return h['return']
        else:
            return None

    def _callback(self, msg):
        """
        The callback is passed an AMQP Message, parses it and calls
        the appropriate method.
        """
#        self.chan.basic_cancel("reply_recvd")
        self.reply = True
        self.response = msg
