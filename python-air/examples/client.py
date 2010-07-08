#!/usr/bin/python
import sys

sys.path.append("..")

from AIR.Client import Client, Timeout

fido = Client(amqp_host = "rmq", amqp_user = "air",
               amqp_pass = "air", amqp_vhost = "AIR")

print fido.call("dog", timeout=None, count=5)
print fido.call("cat", timeout=None, count=20)
print fido.call("man", timeout=None, count=10)
try:
    print fido.call("squirrel", timeout=5.0, count=20)
except Timeout:
    print "No answer"


