# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
Gem::Specification.new do |s|
  s.name        = "air"
  s.version     = "0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["David Greaves"]
  s.email       = ["david@dgreaves.com"]
  s.homepage    = "http://github.com/lbt/air"
  s.summary     = "AMQP-based Interoperable RPC"
  s.description = "Air provides a consistent interface for calling services offered over AMQP. If you're using AMQP for messaging then AIR can supplement that."
 
  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "air"
 
  s.add_development_dependency "rspec"
 
  s.files        = Dir.glob("{lib}/**/*") + %w(LICENSE)
  s.bindir  = ['']
  s.executables  = ['']
  s.require_path = 'lib'
end
