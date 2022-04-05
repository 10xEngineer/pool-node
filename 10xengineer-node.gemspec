# -*- encoding: utf-8 -*-
require File.expand_path('../lib/10xengineer-node/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Radim Marek"]
  gem.email         = ["radim@10xengineer.me"]

  gem.description   = %q{Internal 10xEngineer Labs hostnode tool chain}
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
  gem.add_dependency "yajl-ruby", ">= 1.1", "< 1.5"
  gem.add_dependency "httparty", "~> 0.8.3"
  gem.add_dependency "zfs", "~> 0.1.1"
  gem.add_dependency "mixlib-shellout", "~> 1.1.0"
  gem.add_dependency "erubis", "~> 2.7.0"
  gem.add_dependency "human_size_to_number", "~> 1.0.1"

  gem.add_development_dependency "rspec", "~> 2"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "simplecov-rcov"
end
