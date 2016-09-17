# set here, so we live outside MiniTest's use of at_exit (LIFO)
MOVIES_ROOT ||= Dir.mktmpdir
at_exit { FileUtils.remove_entry MOVIES_ROOT }

require 'ostruct'
require 'thread'
require 'securerandom'
require 'minitest/autorun'
require 'fileutils'

require_relative 'mock_config'
require_relative '../title_casing'
require_relative '../utils'

require_relative 'mock_platform'
require_relative 'mock_slack'

require_relative '../commands'
require_relative '../encoder'
require_relative '../ripper'
require_relative '../mover'

SLACK = SlackMock.new

FileUtils.makedirs([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])
