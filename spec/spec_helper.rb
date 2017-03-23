$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require 'active_support/all'
require 'rspec'
require 'sqlite3'

require "static_models"
require 'byebug'

# Require our macros and extensions
Dir[File.expand_path('../../spec/support/macros/**/*.rb', __FILE__)].map(&method(:require))

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:expect, :should] }
  config.include DatabaseMacros
end
