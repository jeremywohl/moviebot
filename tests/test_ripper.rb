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
TINFO:0,27,0,"A_Story_t00.mkv"
TINFO:1,9,0,"1:45:22"
TINFO:1,10,0,"29.0 GB"
TINFO:1,27,0,"A_Story_t01.mkv"
    EOS
    
    sleep 0.2

    slack_response = <<-EOS
This disc contains the following tracks:
1) A_Story_t00.mkv [1:45:22, 29.0G]
2) A_Story_t01.mkv [1:45:22, 29.0G]
You can tell me to "rip 1[,2,3,..]" or "rip all" or "eject".
    EOS
    
    assert_equal(slack_response.chomp, SLACK.pop)
  end

end
