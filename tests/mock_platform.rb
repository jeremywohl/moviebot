#
# Platform mock
#

require 'fileutils'

class PlatformMock

  attr :disc_in_drive
  attr :mkv_response
  
  def initialize
    @disc_in_drive = false
    @mkv_response  = ''

    @lockstep = Mutex.new
  end

  def disc_present?
    @disc_in_drive
  end

  def eject
    @lockstep.synchronize do
      @disc_in_drive = false
      @mkv_response  = ''
    end
    true
  end
  
  def disc_list(minlength=MKV_SCAN_MINLENGTH * 60)
    @mkv_response
  end
  
  def disc_rip(title, dest_dir, minlength=MKV_SCAN_MINLENGTH * 60)
  end

  def encode(input, output)
    FileUtils.touch(output)
    return "", 0
  end

  def sleep_idle
    @lockstep.synchronize do
      sleep 0.1
    end
  end
  
  def sleep_slow_wait
    @lockstep.synchronize do
      sleep 0.1
    end
  end

  #
  # mock controls
  #

  # TODO: expose spinner states, so tests can wait precisely on edge trigger

  def reset_state
    eject
    DISC_SPINNER.set_state :idle
    sleep_slow_wait
  end

  def simulate_mkv_with_response(r)
    @lockstep.synchronize do
      @mkv_response  = r
      @disc_in_drive = true
    end
  end

end

PLATFORM = PlatformMock.new
