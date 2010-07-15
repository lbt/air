#!/usr/bin/python
import sys

sys.path.append("..")

from AIR.Client import Client, Timeout

air_server = Client(amqp_host = "amqpvm", amqp_user = "air",
               amqp_pass = "air", amqp_vhost = "AIR")

print air_server.call("dog", timeout=None, count=5)
print air_server.call("cat", timeout=None, count=20)
print air_server.call("man", timeout=None, count=10)
try:
    print air_server.call("squirrel", timeout=5.0, count=20)
except Timeout:
    print "No answer"


