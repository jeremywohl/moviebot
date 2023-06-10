# set here, so we live outside MiniTest's use of at_exit (LIFO)
require 'tmpdir'
MOVIES_ROOT ||= Dir.mktmpdir
at_exit { FileUtils.remove_entry MOVIES_ROOT }

require 'ostruct'
require 'thread'
require 'securerandom'
require 'minitest/autorun'
require 'fileutils'
require 'erb'
require 'securerandom'
require 'json'

require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'sequel'

require_relative 'mock_config'
require_relative '../movie_set'
require_relative '../title_casing'
require_relative '../utils'

require_relative 'mock_cloud_aws'
require_relative 'mock_platform'
require_relative 'mock_slack'

require_relative '../commands'
require_relative '../database'
require_relative '../encoder'
require_relative '../encode_cloudly'
require_relative '../encode_locally'
require_relative '../mover'
require_relative '../ripper'

$shutdown = false

SLACK = SlackMock.new
CLOUD = CloudAwsMock.new

DB = Database.open_and_migrate
require_relative '../models'

FileUtils.makedirs([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])

ENCODER = Encoder.start_async(EncodeCloudly)
RIPPER  = Ripper.start_async

# Update a constant (do the impossible!) without warnings.
# constant must be a symbol
# returns old value
def change_constant(const, value)
  raise 'const must be a symbol' if const.class != Symbol
  old_value = Object.const_get(const) rescue nil
  Object.send(:remove_const, const) if Object.const_defined?(const)
  Object.const_set(const, value)
  old_value
end
