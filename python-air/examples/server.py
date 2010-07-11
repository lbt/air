#!/usr/bin/python
import sys

sys.path.append("..")

from AIR.Server import Server


class Animal(object):
    def __init__(self, noise):
        self.noise=noise

    def shout(self, *args, **kwargs):
        print "In self.shout"
        print "args"
        print args
        print "kwargs"
        print kwargs
        if 'count' in kwargs:
            return self.noise * kwargs['count']
        else:
            return self.noise

def shout(*args, **kwargs):
    print "In shout"
    print "args"
    print args
    print "kwargs"
    print kwargs
    if 'count' in kwargs:
        return "hey!" * kwargs['count']
    else:
        return "hey!"




fido=Animal("bark")
fluffy=Animal("meow")

srv = Server(amqp_host = "rmq", amqp_user = "air",
                 amqp_pass = "air", amqp_vhost = "AIR")

srv.register("dog", fido.shout)
srv.register("cat", fluffy.shout)
srv.register("man", shout)

srv.run()
