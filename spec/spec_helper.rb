# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_extensions/pry'
require 'service_protocol'

RSpec.configure do |config|
  if ENV['_'].to_s.match?(/guard/)
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true
  end
end