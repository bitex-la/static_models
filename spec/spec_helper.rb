$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "static_models"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:expect, :should] }
end
