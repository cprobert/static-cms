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

  spec.add_dependency "cprobert-s3sync"
  spec.add_dependency "maruku"
  spec.add_dependency "sass"
  spec.add_dependency "packr"
  spec.add_dependency "filewatcher"
  spec.add_dependency "webrick"
  spec.add_dependency "launchy"
  
  #spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
