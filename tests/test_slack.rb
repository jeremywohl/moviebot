#
# Test Slack
#

require_relative 'common'

class TestSlack < MiniTest::Test

  def test_help
    SLACK.say 'help'
    assert_match(/^Here are common things you can say to me/, SLACK.pop)
  end

  def test_huh
    SLACK.say 'foo'
    assert_match(/^Huh\?/, SLACK.pop)
  end

end
