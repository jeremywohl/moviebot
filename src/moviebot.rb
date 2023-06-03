#!/usr/bin/env ruby

#
# moviebot
#
#

require 'fileutils'
require 'json'
require 'net/http'
require 'openssl'
require 'ostruct'
require 'securerandom'
require 'stringio'
require 'tempfile'
require 'thread'
require 'webrick'

require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'aws-sdk-ec2'
require 'aws-sdk-s3'
require 'childprocess'
require 'concurrent'
require 'net/scp'
require 'net/ssh'
require 'retryable'
require 'sequel'

require_relative '../config'
require_relative 'platform'
require_relative 'movie_set'
require_relative 'title_casing'
require_relative 'utils'

require_relative 'cloud_aws'
require_relative 'commands'
require_relative 'database'
require_relative 'encode_cloudly'
require_relative 'encode_locally'
require_relative 'encoder'
require_relative 'mover'
require_relative 'ripper'
require_relative 'slack'

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
CLOUD   = CloudAws.new if USE_CLOUD
ENCODER = Encoder.start_async(USE_CLOUD ? EncodeCloudly : EncodeLocally)

# wait on completion
SLACK.start_sync

log :info, 'exit'
