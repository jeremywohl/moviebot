# Format the interval between now and +tstart+, e.g. 3s or 15m:20s or 2h:21m.
def format_time_diff(tstart)
  diff = Time.now - tstart
  if diff < 60
    sprintf "%ds", diff
  elsif diff < 60 * 60
    sprintf "%dm:%ds", diff / 60, diff % 60
  else
    sprintf "%dh:%dm", diff / (60 * 60), diff % (60 * 60) / 60
  end
end

# Convenience method for Slack notifications.
def notify(msg, opts={})
  SLACK.notify(msg, opts)
end

# Run a shell command, capturing STDOUT.
def external(cmd, opts={})
  _external(cmd, opts)
end

# Run a shell command, returning STDOUT capture & timing string.
def external_with_timing(cmd, opts={})
  opts[:timing] = true
  _external(cmd, opts)
end

def _external(cmd, opts={})
  log :info, "starting #{cmd}" if !opts.has_key?(:silent)

  cmd << " 2>&1"

  start = Time.now
  result = %x(#{cmd})
  diff = format_time_diff(start)
  
  log :info, "ran [#{cmd}] in #{diff}" if !opts.has_key?(:silent)
  
  if opts.has_key?(:timing)
    return result, diff
  else
    return result
  end
end

LOG_MUTEX = Mutex.new

# Send messages to STDOUT with timestamp and +channel+ :info, :error or
# :debug.  Logs to :debug are a noop when config var LOG_DEBUG = false.
# +msg+ may a multi-line string (and will be split across log messages)
# or array of strings. An exception passed in opts (e.g. exception: e)
# gets a formatted backtrace.
#
#   log :info, "hello"
#
#   log :error, "this is awful!", exception: e
def log(channel, msg, opts={})
  return if channel == :debug && LOG_DEBUG == false

  tag = case channel
  when :info
    ' INFO'
  when :error
    'ERROR'
  when :debug
    'DEBUG'
  end

  prefix = "[#{Time.now.to_s} #{tag}]"

  msgs = case msg
  when String
    msg.lines
  when Array
    msg
  else
    raise 'msg must be an Array or String'
  end

  LOG_MUTEX.synchronize do
    msgs.each { |m| puts "#{prefix} #{m.chomp}" }

    if opts.has_key?(:exception)
      e = opts[:exception]
      puts "#{prefix}   #{e.backtrace.first}: #{e.message} (#{e.class})"
      e.backtrace.drop(1).map { |s| puts "#{prefix}     " << s }
    end
  end
end

# Generate a plural phrase, using +singular+ when +count+ is 1,
# and +plural+ otherwise.
#
#   pluralize(1, 'person', 'people)   # => 1 person
#
#   pluralize(2, 'person', 'people')  # => 2 people
#
#   pluralize(3, 'person', 'users')   # => 3 users
#
#   pluralize(0, 'person', 'people')  # => 0 people
def pluralize(count, singular, plural)
  word = count == 1 ? singular : plural
  "#{count || 0} #{word}"
end
