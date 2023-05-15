#
# Platform-specific behavior
#

MKV_LIST = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot info disc:0"
MKV_RIP  = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot mkv disc:0"

ENCODE = %(#{HANDBRAKE_BIN} --input "%{input}" --output "%{output}" --preset '#{HANDBRAKE_PROFILE}')

class MacPlatform

  # Notes:
  #   drutil prints three kinds of results:
  #     1) empty (no drive),
  #     2) /*No Media*/ when existing drive is empty,
  #     3) named media
  def disc_present?
    result   = external('/usr/bin/drutil status', silent: true).strip
    no_drive = result.empty?
    no_media = !result.lines.grep(/No Media/).empty?
    return ( no_drive || no_media ) ? false : true
  end

  def eject
    result, timing = external_with_timing '/usr/bin/drutil eject'
  end

  def disc_list(minlength=MKV_SCAN_MINLENGTH * 60)
    cmd = MKV_LIST % { minlength: MKV_SCAN_MINLENGTH * 60 }
    external(cmd)
  end

  def disc_rip(movie, minlength=MKV_SCAN_MINLENGTH * 60)
    rip_cmd = "#{MKV_RIP % { minlength: minlength }} #{movie.track_id} \"#{movie.rip_dir}\""
    results, timing = external_with_timing rip_cmd
  end

  def encode(movie)
    encode_cmd = ENCODE % { input: movie.rip_fn, output: movie.encode_fn }
    result, timing = external_with_timing encode_cmd
  end

  def sleep_idle
    sleep 10
  end
  
  def sleep_slow_wait
    sleep 1
  end

  # Movie volume free space in gibabytes.
  def free_space
    `df -H #{MOVIES_ROOT}`.lines[-1].split[3].to_i
  end

end

PLATFORM = case RUBY_PLATFORM
when /darwin/
  MacPlatform.new
# when /win32/
#   WindowsPlatform.new
# when /linux/
#   LinuxPlatform.new
else
  log :error, "Sorry, we don't support platform #{RUBY_PLATFORM}."
  exit 1
end
