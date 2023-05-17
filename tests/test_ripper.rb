#
# Test ripper
#

require_relative 'common'

class TestRipper < MiniTest::Test

  def teardown
    PLATFORM.reset_state
    SLACK.clear
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

end
