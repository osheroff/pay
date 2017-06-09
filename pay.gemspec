$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "pay"
  s.version     = Pay::VERSION
  s.authors     = ["Jason Charnes"]
  s.email       = ["jason@thecharnes.com"]
  s.homepage    = "https://github.com/jasoncharnes/pay"
  s.summary     = "A wrapper for handing subscriptions in Rails."
  s.description = "A wrapper for handing subscriptions in Rails."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 4.2"
  s.add_dependency "stripe", "~> 1.0"

  s.add_development_dependency 'pry'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'stripe-ruby-mock', '~> 2.4'
end