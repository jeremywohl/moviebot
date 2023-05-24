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
require 'tempfile'

require 'concurrent'
require 'sequel'
require 'childprocess'
require 'active_support'
require 'active_support/core_ext/hash/keys'

require_relative '../config'
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

$shutdown = false

DB = Database.open_and_migrate
require_relative 'models'

log :info, 'start'

FileUtils.makedirs([ RIPPING_ROOT, ENCODING_ROOT, DONE_ROOT ])

SLACK = Slack.new

%w( INT TERM ).each do |sig|
  trap sig do
    $shutdown = true

    halt_subprocesses  # TODO: may fail for thread lock reasons
    SLACK.closeup      # TODO: may fail for thread lock reasons
  end
end

# background
RIPPER  = Ripper.start_async
ENCODER = Encoder.start_async

# wait on completion
SLACK.start_sync

log :info, 'exit'
