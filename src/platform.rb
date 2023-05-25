#
# Platform-specific behavior
#

class MacPlatform

  MKV_LIST = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot info disc:0"
  MKV_RIP  = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot mkv disc:0 %{track_id} %{rip_dir}"

  ENCODE = "#{HANDBRAKE_BIN} --input %{input} --output %{output} --preset %{profile}"
  
  # Notes:
  #   drutil prints three kinds of results:
  #     1) empty (no drive),
  #     2) /*No Media*/ when existing drive is empty,
  #     3) named media
  def disc_present?
    _, result = external([ '/usr/bin/drutil', 'status' ], silent: true)
    result.strip!
    no_drive  = result.empty?
    no_media  = !result.lines.grep(/No Media/).empty?
    return ( no_drive || no_media ) ? false : true
  end

  def eject
    _, result, timing = external_with_timing [ '/usr/bin/drutil', 'eject' ]
  end

  def disc_list(minlength=MKV_SCAN_MINLENGTH * 60)
    cmd = interpolate_cmd(MKV_LIST, { minlength: MKV_SCAN_MINLENGTH * 60 })
    _, result = external cmd
    return result
  end

  def disc_rip(movie, minlength=MKV_SCAN_MINLENGTH * 60)
    cmd = interpolate_cmd(MKV_RIP, { minlength: minlength, track_id: movie.track_id, rip_dir: movie.rip_dir })
    external_with_timing cmd
  end

  def encode(movie)
    cmd = interpolate_cmd(ENCODE, { input: movie.rip_fn, output: movie.encode_fn, profile: HANDBRAKE_PROFILE })
    external_with_timing cmd
  end

  def drive_locked?
    # On a Mac, disc ejection will be prevented when the computer is locked
    `ioreg -n Root -d1 -a | grep ScreenIsLocked`.strip.length > 0
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
