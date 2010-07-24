#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
Bundler.setup

$LOAD_PATH << './lib'
require 'AIR/Server'



class Animal
  def initialize(noise)
    @noise=noise
  end

  def shout(args, kwargs)
    puts "In self.shout"
    puts "args"
    puts args
    puts "kwargs"
    puts kwargs
    if kwargs.has_key? 'count'
        return @noise * kwargs['count']
    else
      return @noise
    end
  end
end

def shout(args, kwargs)
  puts "In shout"
  puts "args"
  puts args
  puts "kwargs"
  kwargs.each do |key, val|
    puts "#{key} => #{val}"
  end
  if kwargs.has_key? 'count'
      return "hey! " * kwargs['count']
  else
    return "hey!"
  end
end


fido=Animal.new("bark ")
fluffy=Animal.new("meow ")

srv = AIR::Server.new(:host => "amqpvm", :user => "air",
                      :pass => "air", :vhost => "AIR")

srv.register("dog", fido.method(:shout))
srv.register("cat", fluffy.method(:shout))
srv.register("man", method(:shout))

srv.run()
