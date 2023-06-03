#
# Slack mock
#

class SlackMock
  
  attr :history

  def initialize
    @history = []
  end
  
  def clear
    @history.clear
  end
  
  def pop
    @history.pop
  end

  def say(s)
    Thread.new { COMMANDS.handle_msg(s) }.join
  end
  
  def send_text_message(s, opts={})
    @history << s
  end

  def send_block_kit_message(s, alt_s, opts)
  end

end
