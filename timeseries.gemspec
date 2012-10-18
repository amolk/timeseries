# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timeseries/version'

Gem::Specification.new do |gem|
  gem.name          = "timeseries"
  gem.version       = Timeseries::VERSION
  gem.authors       = ["Amol Kelkar"]
  gem.email         = ["kelkar.amol@gmail.com"]
  gem.description   = %q{Store timeseries data to mongodb and query by range and granularity}
  gem.summary       = %q{Store timeseries data to mongodb and query by range and granularity}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
