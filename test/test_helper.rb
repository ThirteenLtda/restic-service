$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "restic/service"

require "minitest/spec"
require 'flexmock/minitest'
require "minitest/autorun"

begin
    require 'pry'
rescue LoadError
end
