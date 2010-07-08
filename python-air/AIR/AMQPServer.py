import sys, traceback
from amqplib import client_0_8 as amqp
import simplejson as json

class AMQPServer(object):
    """
    The AIR.AMQPServer is a convenient object that represents an AMQP
    server. It holds AMQP server details.
    """
    def __init__(self, 
                 amqp_host = "localhost", amqp_user = "air",
                 amqp_pass = "air", amqp_vhost = "AIR"):
        self.host = amqp_host
        self.user = amqp_user
        self.pw = amqp_pass
        self.vhost = amqp_vhost
        self.conn = amqp.Connection(host=self.host,
                                     userid=self.user,
                                     password=self.pw,
                                     virtual_host=self.vhost,
                                     insist=False)
        self.chan = self.conn.channel()
