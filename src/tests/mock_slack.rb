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
  
  def notify(s, opts={})
    @history << s
  end

end
