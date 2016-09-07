#
# Platform-specific behavior
#

MKV_LIST = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot info disc:0"
MKV_RIP  = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot mkv disc:0"

ENCODE = %(#{HANDBRAKE_BIN} --input "%{input}" --output "%{output}" --preset '#{HANDBRAKE_PROFILE}')

class MacPlatform

  def disc_present?
    external('/usr/bin/drutil status', silent: true).lines.grep(/No Media/).empty?
  end

  def eject
    result, timing = external_with_timing '/usr/bin/drutil eject'
  end

  def disc_list(minlength=MKV_SCAN_MINLENGTH * 60)
    cmd = MKV_LIST % { minlength: MKV_SCAN_MINLENGTH * 60 }
    external(cmd)
  end

  def disc_rip(title, dest_dir, minlength=MKV_SCAN_MINLENGTH * 60)
    rip_cmd = "#{MKV_RIP % { minlength: minlength }} #{title} \"#{dest_dir}\""
    results, timing = external_with_timing rip_cmd
  end

  def encode(input, output)
    encode_cmd = ENCODE % { input: input, output: output }
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
