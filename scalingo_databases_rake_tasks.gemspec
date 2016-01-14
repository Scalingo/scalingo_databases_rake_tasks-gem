# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scalingo_databases_rake_tasks/version'

Gem::Specification.new do |spec|
  spec.name          = "scalingo_databases_rake_tasks"
  spec.version       = ScalingoDbTasks::VERSION
  spec.authors       = ["Scalingo"]
  spec.email         = ["hello@scalingo.com"]

  spec.summary       = %q{Perform database related tasks on Scalingo.}
  spec.description   = %q{Perform database related tasks on Scalingo.}
  spec.homepage      = "https://github.com/Scalingo/scalingo_databases_rake_tasks-gem"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
