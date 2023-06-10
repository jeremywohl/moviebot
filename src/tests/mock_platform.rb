#
# Platform mock
#

class PlatformMock

  attr :disc_in_drive
  attr :mkv_response
  
  def initialize
    @disc_in_drive = false
    @mkv_response  = ''
  end

  def disc_present?
    @disc_in_drive
  end

  def drive_locked?
    false
  end

  def eject
    @disc_in_drive = false
    @mkv_response  = ''
    true
  end
  
  def disc_list(minlength=MKV_SCAN_MINLENGTH * 60)
    @mkv_response
  end
  
  def disc_rip(title, dest_dir, minlength=MKV_SCAN_MINLENGTH * 60)
  end

  def encode(movie)
    FileUtils.touch(movie.encode_fn)
    return 0, "", "0s"
  end

  def sleep_idle
    sleep 0.1
  end
  
  def sleep_slow_wait
    sleep 0.1
  end
  
  def free_space
    22
  end

  #
  # mock controls
  #

  # TODO: expose spinner states, so tests can wait precisely on edge trigger

  def reset_state
    eject
    RIPPER.set_state :idle
    sleep_slow_wait
  end

  def simulate_mkv_with_response(r)
    @mkv_response  = r
    @disc_in_drive = true
  end

end

PLATFORM = PlatformMock.new
