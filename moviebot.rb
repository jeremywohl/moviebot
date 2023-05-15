#!/usr/bin/env ruby

#
# moviebot
#
#

require 'ostruct'
require 'thread'
require 'securerandom'
require 'net/http'
require 'webrick'
require 'json'
require 'openssl'
require 'fileutils'

require 'concurrent'
require 'sequel'

require_relative 'config'
require_relative 'title_casing'
require_relative 'utils'
require_relative 'platform'

require_relative 'commands'
require_relative 'encoder'
require_relative 'ripper'
require_relative 'mover'
require_relative 'slack'
require_relative 'database'

STDOUT.sync = true
STDERR.sync = true

DB = Database.open_and_migrate
require_relative 'models'

log :info, 'start'

FileUtils.makedirs([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])

SLACK = Slack.new

%w( INT TERM ).each do |sig|
  trap sig do
    # TODO: close ripper / encoder
    SLACK.closeup
  end
end

# background
RIPPER  = Ripper.start_async
ENCODER = Encoder.start_async

# wait on completion
SLACK.start_sync

log :info, 'exit'
