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

require 'sequel'
require 'active_support'
require 'active_support/core_ext/hash/keys'

require_relative 'mock_config'
require_relative '../title_casing'
require_relative '../utils'

require_relative 'mock_platform'
require_relative 'mock_slack'

require_relative '../commands'
require_relative '../encoder'
require_relative '../ripper'
require_relative '../mover'
require_relative '../database'

SLACK = SlackMock.new

DB = Database.open_and_migrate
require_relative '../models'

FileUtils.makedirs([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])

ENCODER = Encoder.start_async
RIPPER  = Ripper.start_async
