# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'Scms/version'

Gem::Specification.new do |spec|
  spec.name          = "scms"
  spec.version       = Scms::VERSION

  spec.required_ruby_version = '>= 1.9.1'

  spec.authors       = ["Courtenay Probert"]
  spec.email         = ["courtenay@probert.me.uk"]
  spec.description   = "A static website CMS for Amazon's S3"
  spec.summary       = "Create simple static websites, in a jiffy"
  spec.homepage      = "http://cprobert.github.io/Static-CMS/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)

  spec.files.grep(%r{^bin/.*}) { |f| 
    puts "exe: #{f}"
  }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.executables << 'scms'

  spec.add_dependency 'cprobert-s3sync'

  spec.add_dependency 'maruku', '~> 0.7'
  spec.add_dependency 'packr', '~> 3.2'
  spec.add_dependency 'listen', '~> 2.5'
  spec.add_dependency 'filewatcher', '~> 0.3'
  spec.add_dependency 'webrick', '~> 1.3'
  spec.add_dependency 'launchy', '~> 2.4'
  spec.add_dependency 'nokogiri', '~> 1.6'

  #spec.add_runtime_dependency 'sass', , '>= 3.2.14'
  spec.add_dependency('sass', '~> 3.2')
  
  #spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", '~> 10.1', '>= 10.1.1'
end
