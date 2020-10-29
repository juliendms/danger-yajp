# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yajp/gem_version'

Gem::Specification.new do |spec|
  spec.name          = 'danger-yajp'
  spec.version       = Yajp::VERSION
  spec.authors       = ['juliendms']
  spec.email         = ['j-dumas@live.fr']
  spec.description   = 'Synchronize your Jira issues with your PR/MR, and more.'
  spec.summary       = 'Yet Another Jira Plugin is a danger plugin to find issues, access their parameters and perform operations on them.'
  spec.homepage      = 'https://github.com/juliendms/danger-yajp'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6.0'

  spec.add_runtime_dependency 'danger-plugin-api'
  spec.add_runtime_dependency 'jira-ruby'

  # General ruby development
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13.0'

  # Testing support
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'webmock', '~> 3.9'

  # Linting code and docs
  spec.add_development_dependency 'rubocop', '~> 1.0.0'
  spec.add_development_dependency 'yard', '~> 0.9.11'

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency 'guard', '~> 2.16'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'

  # This gives you the chance to run a REPL inside your tests
  # via:
  #
  #    require 'pry'
  #    binding.pry
  #
  # This will stop test execution and let you inspect the results
  spec.add_development_dependency 'pry'
end
