#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
Bundler.setup

$LOAD_PATH << './lib'
require 'AIR/Client'

fido = AIR::Client.new(:host => "rmq", :user => "air",
                       :pass => "air", :vhost => "AIR")

puts fido.call("dog", :timeout => nil, :count => 5)
puts fido.call("cat", :timeout => nil, :count => 20)
puts fido.call("man", :timeout => nil, :count => 10)
begin
    puts fido.call("squirrel", :timeout => 5.0, :count => 20)
rescue AIR::Timeout
    puts "No answer"
end


