#!/usr/bin/env ruby

#
# moviebot
#
#

require 'ostruct'
require 'thread'
require 'securerandom'
require 'net/http'
require 'json'
require 'openssl'

require 'websocket/driver'
require 'concurrent'

require_relative 'config'
require_relative 'title_casing'
require_relative 'utils'

require_relative 'commands'
require_relative 'encoder'
require_relative 'ripper'
require_relative 'mover'
require_relative 'slack'

STDOUT.sync = true
STDERR.sync = true

log :info, 'start'

SLACK = Slack.new

trap "SIGINT" do
  SLACK.closeup
end

SLACK.go

log :info, 'exit'
