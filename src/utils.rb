SUBPROCS = []  # currently running subprocesses of moviebot

# Format the interval between now and +tstart+, e.g. 3s or 15m:20s or 2h:21m.
def format_time_diff(tstart)
  diff = Time.now - tstart
  format_time(diff)
end

# Present time as 59s or 59m:59s or 23h:36m.
def format_time(seconds)
  if seconds < 60
    sprintf "%ds", seconds
  elsif seconds < 60 * 60
    sprintf "%dm:%02ds", seconds / 60, seconds % 60
  else
    sprintf "%dh:%02dm", seconds / (60 * 60), seconds % (60 * 60) / 60
  end
end

# Present in gigabytes (powers of 10), 27.4G.
def format_size(bytes)
  sprintf "%0.1fG", bytes.to_f / 10**9
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

# cmd is an array of path elements, e.g. [ '/bin/bash', '-c', 'echo foo' ]
def _external(cmd, opts={})
  log :info, "cmd is ||#{cmd.inspect}||"
  log :info, "starting [#{cmd.join(' ')}]" if !opts.has_key?(:silent)

  # setup
  process = ChildProcess.build(*cmd)
  process.io.stdout = process.io.stderr = Tempfile.new

  # run
  SUBPROCS << process  # add to halt list
  start = Time.now
  process.start
  process.wait
  diff  = format_time_diff(start)
  SUBPROCS.delete_if { |p| p.pid == process.pid }  # remove from halt list

  # gather output
  process.io.stdout.rewind
  result = process.io.stdout.read
  process.io.stdout.close!
  
  log :info, "ran [#{cmd.join(' ')}] in #{diff}" if !opts.has_key?(:silent)
  
  if process.exit_code > 0 && !$shutdown
    log :error, "command [#{cmd.join(' ')}] returned an error (code #{process.exit_code}), with the following output"
    log :error, result
  end

  if opts.has_key?(:timing)
    return process.exit_code, result, diff
  else
    return process.exit_code, result
  end
end

def halt_subprocesses
  log :info, "Halting ripping/encoding..." if SUBPROCS.any?
  SUBPROCS.each { |p| p.stop }
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

  # Note: we cannot use mutexes/etc directly from a signal trap, and since we log everywhere,
  # including shutdown procedures, start a new thread, taking the mutex out-of-band to the signaled thread
  Thread.new do
    LOG_MUTEX.synchronize do
      msgs.each { |m| puts "#{prefix} #{m.chomp}" }

      if opts.has_key?(:exception)
        e = opts[:exception]
        puts "#{prefix}   #{e.backtrace.first}: #{e.message} (#{e.class})"
        e.backtrace.drop(1).map { |s| puts "#{prefix}     " << s }
      end
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

def render_template(basename, vars_hash)
  template_fn = File.join(File.expand_path(File.dirname(__FILE__)), 'templates', basename)
  ERB.new(File.read(template_fn), trim_mode: "%>").result_with_hash(vars_hash)
end

$encryption_key = SecureRandom.random_bytes(ActiveSupport::MessageEncryptor.key_len)

# Encrypt hash, with authentication.
# TODO: is this thread-safe, can we cache encryptor?
def encrypt_hash(hash)
  encryptor = ActiveSupport::MessageEncryptor.new($encryption_key)
  encryptor.encrypt_and_sign(hash.to_json)
end

# Decrypts into hash, or nil, if the text fails authentication.
def decrypt_hash(encrypted_blob)
  encryptor = ActiveSupport::MessageEncryptor.new($encryption_key)
  decrypted = encryptor.decrypt_and_verify(encrypted_blob)

  if decrypted.nil?
    return nil
  else
    return JSON.parse(decrypted)
  end
end

# Generate a humanized list, e.g. a, b, and c.
def human_list(list)
  case list.length
  when 0
    ""
  when 1
    list[0]
  when 2
    "#{list[0]} and #{list[1]}"
  else
    "#{list[0...-1].join(', ')}, and #{list[-1]}"
  end
end

# Split a string into an array and Ruby %{var} interpolate each segment.
# Whitespace is preserved after splitting, so substitutions can include
# spaces, suitable for passing complex filenames to a subprocess.
def interpolate_cmd(input, vars)
  input.split.map { |field| field % vars }
end