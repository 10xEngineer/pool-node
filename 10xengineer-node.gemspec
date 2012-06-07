# -*- encoding: utf-8 -*-
require File.expand_path('../lib/10xengineer-node/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Radim Marek"]
  gem.email         = ["radim@laststation.net"]

  gem.description   = %q{10xEngineer.me hostnode management toolchain}
  gem.summary       = %q{}
  gem.homepage      = "http://10xengineer.me/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "10xengineer-node"
  gem.require_paths = ["lib"]
  gem.version       = TenxEngineer::Node::VERSION

  gem.add_dependency "commander", "~> 4.1.2"
  gem.add_dependency "net-ssh", "~> 2.3.0"
  gem.add_dependency "uuid", "~> 2.3.5"
  gem.add_dependency "open4", "~> 1.3.0"
  gem.add_dependency "di-ruby-lvm", "~> 0.1.3"
  gem.add_dependency "yajl-ruby", "~> 1.1.0"

  gem.add_development_dependency "rspec", "~> 2"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "simplecov-rcov"
end
