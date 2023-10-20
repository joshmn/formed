# frozen_string_literal: true

require_relative "lib/formed/version"

Gem::Specification.new do |spec|
  spec.name        = "formed"
  spec.version     = Formed::VERSION
  spec.authors     = ["Josh"]
  spec.email       = ["josh@josh.mn"]
  spec.homepage    = "https://github.com/joshmn/formed"
  spec.summary     = "A form object that really wants to be a form object."
  spec.description = spec.summary
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 5.2"

  spec.add_development_dependency "codecov"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-rails"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "timecop"
end
