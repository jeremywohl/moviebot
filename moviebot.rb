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
require 'fileutils'

require 'websocket/driver'
require 'concurrent'

require_relative 'config'
require_relative 'title_casing'
require_relative 'utils'
require_relative 'platform'

require_relative 'commands'
require_relative 'encoder'
require_relative 'ripper'
require_relative 'mover'
require_relative 'slack'

STDOUT.sync = true
STDERR.sync = true

log :info, 'start'

SLACK = Slack.new

FileUtils.mkdir([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])

%w( INT TERM ).each do |sig|
  trap sig do
    SLACK.closeup
  end
end

SLACK.go

log :info, 'exit'
