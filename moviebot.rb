#!/usr/bin/env ruby

#
# moviebot
#
#

require 'ostruct'
require 'thread'
require 'securerandom'

require 'slack-ruby-client'

require_relative 'config'
require_relative 'title_casing'
require_relative 'utils'

require_relative 'commands'
require_relative 'encoder'
require_relative 'ripper'
require_relative 'mover'
require_relative 'slack'

STDOUT.sync = true
