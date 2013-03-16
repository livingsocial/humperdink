# -*- encoding: utf-8 -*-
require File.expand_path('../lib/humperdink/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = %w(chrismo)
  gem.email         = %w(chris.morris@livingsocial.com)
  gem.description   = %q{Runtime tracking of finite data sets}
  gem.summary       = %q{Runtime tracking of finite data sets}
  gem.homepage      = 'https://github.com/livingsocial/humperdink'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec|spec|features)/})
  gem.name          = 'humperdink'
  gem.require_paths = %w(lib)
  gem.version       = Humperdink::VERSION

  gem.add_dependency 'i18n', '0.6.1'
  gem.add_dependency 'hiredis', '~> 0.4.5'
  gem.add_dependency 'redis', '~> 2.2.0'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'json'
  gem.add_development_dependency 'resque'
end
