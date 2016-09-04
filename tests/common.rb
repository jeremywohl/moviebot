require 'ostruct'
require 'thread'
require 'securerandom'
require 'minitest/autorun'

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
