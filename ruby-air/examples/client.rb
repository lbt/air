#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
Bundler.setup

$LOAD_PATH << './lib'
require 'AIR/Client'

air_server = AIR::Client.new(:host => "amqpvm", :user => "air",
                       :pass => "air", :vhost => "AIR")

puts air_server.call("dog", :timeout => nil, :count => 5)
puts air_server.call("cat", :timeout => nil, :count => 20)
puts air_server.call("man", :timeout => nil, :count => 10)
begin
    puts air_server.call("squirrel", :timeout => 5.0, :count => 20)
rescue AIR::Timeout
    puts "No answer"
end


