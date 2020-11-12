# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'static_models/version'

Gem::Specification.new do |spec|
  spec.name          = "static_models"
  spec.version       = StaticModels::VERSION
  spec.authors       = ["nubis"]
  spec.email         = ["yo@nubis.im"]

  spec.summary       = %q{DRY your key-value classes. Use them as associations}
  spec.description   = %q{
    Replace your key/value classes with this.
    Define classes with several 'singleton' instances.
  }
  spec.homepage      = "https://github.com/bitex-la/static_models"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "activesupport", '~> 5.0'
  spec.add_dependency "activemodel",'~> 5.0'

  spec.add_development_dependency "bundler", "~> 1.17.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activerecord", '~> 5.0'
  spec.add_development_dependency "sqlite3", "~> 1.0", ">= 1.0.0"
  spec.add_development_dependency "byebug", "~> 6.0", ">= 6.0.0"
end
