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

  spec.add_runtime_dependency 'cprobert-s3sync', '~> 1.4', '>= 1.4.1'
  spec.add_runtime_dependency 'maruku', '~> 0.7', '>= 0.7.1'
  spec.add_runtime_dependency 'sass', '~> 3.2', '>= 3.2.14'
  spec.add_runtime_dependency 'packr', '~> 3.2', '>= 3.2.1'
  spec.add_runtime_dependency 'listen', '~> 2.5', '>= 2.5.0'
  spec.add_runtime_dependency 'filewatcher', '~> 0.3', '>= 0.3.2'
  spec.add_runtime_dependency 'webrick', '~> 1.3', '>= 1.3.1'
  spec.add_runtime_dependency 'launchy', '~> 2.4', '>= 2.4.2'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.1'
  
  #spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", '~> 10.1', '>= 10.1.1'
end
