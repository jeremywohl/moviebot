#
# slack robot
#

SLACK = Slack::RealTime::Client.new token: SLACK_API_TOKEN

SLACK.on :hello do
  channel = SLACK.channels.select { |c| c['name'] == SLACK_CHANNEL }
  if channel.empty?
    STDERR.puts "Sorry, we can't find channel #{SLACK_CHANNEL}; exiting."
    exit 1
  end

  SLACK_CHANNEL_ID = channel.first['id']
  
  notify('Waking up.')
end

SLACK.on :message do |data|
  if data['text'] =~ /\A#{SLACK_CHAT_NAME} /
    COMMANDS.handle_msg(data['text'][SLACK_CHAT_NAME.length+1..-1])
  end
end

SLACK.start!
