#
# Test ripper
#

require_relative 'common'

class TestRipper < MiniTest::Test

  def teardown
    PLATFORM.reset_state
    SLACK.clear
  end

  def setup
    # reset db
    DB[:movies].delete
  end

  def test_app_too_old
    PLATFORM.simulate_mkv_with_response <<-EOS
MSG:5021,260,1,"This application version is too old.  More verbiage here.  Call your mother."
    EOS

    sleep 0.2

    assert_match(/^Hmm, your MakeMKV evaluation period is expired/, SLACK.pop)
    assert_equal(false, PLATFORM.disc_present?)
  end

  def test_insert_disc_ask
    return  # TODO: fix for block kit changes
    PLATFORM.simulate_mkv_with_response <<-EOS
CINFO:30,0,"A_Story"
TINFO:0,9,0,"1:45:22"
TINFO:0,10,0,"29.0 GB"
TINFO:1,11,0,"31138512896"
TINFO:0,27,0,"A_Story_t00.mkv"
TINFO:1,9,0,"1:45:22"
TINFO:1,10,0,"29.0 GB"
TINFO:1,11,0,"31138512896"
TINFO:1,27,0,"A_Story_t01.mkv"
    EOS

    sleep 0.2

    slack_response = <<-EOS
This disc contains the following tracks:
1) A_Story_t00.mkv [1h:45m, 31.1G]
2) A_Story_t01.mkv [1h:45m, 31.1G]
You can tell me to "rip 1[,2,3,..]" or "rip all" or "eject".
    EOS

    assert_equal(slack_response.chomp, SLACK.pop)
  end

  # test truncation -- playlist obfuscation creates fake track lists of hundreds
  def test_copy_protection_playlist
    return  # TODO: fix for block kit changes
    header  = %(CINFO:30,0,"A_Story"\n)
    snippet = <<-EOS
TINFO:0,9,0,"1:45:22"
TINFO:0,10,0,"29.0 GB"
TINFO:1,11,0,"31138512896"
TINFO:0,27,0,"A_Story_t00.mkv"
    EOS
    total   = header + snippet * (Ripper::MAX_TRACK_LIST + 5)

    PLATFORM.simulate_mkv_with_response total
    sleep 0.2

    header  = "This disc contains the following tracks:\n"
    footer1 = ".. list too long, possible copy protection & playlist obfuscation ..\n"
    footer2 = %(You can tell me to "rip 1[,2,3,..]" or "rip all" or "eject".)
    total   = header
    Ripper::MAX_TRACK_LIST.times { |i|
      total += "#{i+1}) A_Story_t00.mkv [1h:45m, 31.1G]\n"
    }
    total   += footer1 + footer2

    assert_equal(total, SLACK.pop)
  end

  def test_cleanup_abandoned_rips
    movie = Movie.new(name: 'abc', track_name: 'abc_t00.mkv', state: 'ripping')
    movie.save
    movie.set_rip_paths
    Dir.mkdir(movie.rip_dir)
    FileUtils.touch(movie.rip_fn)

    assert Dir.exist?(movie.rip_dir)
    assert File.exist?(movie.rip_fn)

    RIPPER.cleanup_abandoned_rips

    assert !Dir.exist?(movie.rip_dir)
    assert_equal 'abandoned', Movie.first(id: movie.id).state
  end

  def test_abandoned_on_eject
    movie = Movie.new(name: 'abc', track_name: 'abc_t00.mkv', state: 'pending')
    movie.save
    movie.set_rip_paths
    Dir.mkdir(movie.rip_dir)
    FileUtils.touch(movie.rip_fn)

    assert Dir.exist?(movie.rip_dir)
    assert File.exist?(movie.rip_fn)

    RIPPER.eject

    assert !Dir.exist?(movie.rip_dir)
    assert_equal 'abandoned', Movie.first(id: movie.id).state
  end

end
