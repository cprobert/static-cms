# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require 'scms/version'

Gem::Specification.new do |s|
  s.name        = 'scms'
  s.version     = StaticCMS::VERSION
  s.date        = '2013-06-29'
  s.homepage    = 'https://github.com/cprobert/Static-CMS'
  s.summary     = "Create simple static websites, in a jiffy"
  s.description = "A gem for creating static html websites"
  s.authors     = ["Courtenay Probert"]
  s.email       = 'courtenay@probert.me.uk'
  s.files       = Dir.glob("**/*")
  
  s.add_dependency "aproxacs-s3sync"
  s.add_dependency "nokogiri"
  s.add_dependency "maruku"
  s.add_dependency "sass"
  s.add_dependency "packr"
  
  s.executables << 'scms'
end