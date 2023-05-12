#
# slack robot
#

class WebrickLogger
  def <<(msg)
    log :debug, "WEBRICK: #{msg}"
  end
end

class Slack

  SLACK_API_PREFIX_URL            = 'https://slack.com/api/'
  SLACK_CONVERSATIONS_LIST_METHOD = 'conversations.list'
  SLACK_POST_MESSAGEL_METHOD      = 'chat.postMessage'

  MAX_SEND_CHARS  = 4_000

  def initialize
    @pending    = Concurrent::Array.new
    @channel_id = nil  # the movies channel id
  end

  def go
    @events_server = self.start_events_server
    
    self.notify('Waking up.')
    self.send_pending

    @events_server.start
  end

  # Receive /movies slash command from Slack Events API.
  def start_events_server
    logger = WEBrick::Log.new(WebrickLogger.new)
    server = WEBrick::HTTPServer.new Port: SLACK_LISTEN_PORT, Host: SLACK_LISTEN_HOST,
      Logger: logger, AccessLog: [ [ logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT ] ]

    server.mount_proc SLACK_SLASH_URI do |request, response|
      self.handle_message(request.query['text'])

      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = '{ "response_type": "in_channel" }'
    end

    return server
  end

  # Call Slack Web API.
  def slack_api(endpoint, token, data, accept_notok=false)
    headers = {
                'Content-type'  => 'application/json',
                'Authorization' => "Bearer #{token}"
              }
    response = Net::HTTP.post(URI.join(SLACK_API_PREFIX_URL, endpoint), data.to_json, headers)

    if response.code != '200'
      log :error, "Sorry, problem connecting to Slack.  Here's what they said."
      log :error, response.body
      exit 1 if accept_notok == false
    end

    data = JSON.parse(response.body) rescue {}

    if data['ok'] != true
      log :error, "Sorry, problem connecting to Slack.  Here's the error: #{data['error']}.  We die."
      log :error, "[response] #{response.inspect}"
      log :error, "[data] #{data.inspect}"
      exit 1 if accept_notok == false
    end

    return data
  end

  def closeup
    Thread.new { SLACK.notify('Goodbye.') }
    @events_server.shutdown
    sleep 1
  end

  def handle_message(command)
    log :info, "slack said: [#{command}]"
    Thread.new { COMMANDS.handle_msg(command) }
  end

  # tell Slack channel something; accepts /poke_channel: true/ to alert the channel.
  def notify(msg, opts={})
    msg = msg[0...MAX_SEND_CHARS-16]+"...truncating..." if msg.size >= MAX_SEND_CHARS
    if opts[:poke_channel]
      if msg.lines.size > 1
        msg << "\n" if msg[-1] != "\n"
        msg << "<!channel> (see above)"
      else
        msg = "<!channel> " << msg
      end
    end

    @pending << msg
    self.send_pending
  end

  def send_pending
    while (msg = @pending.shift)
      if self.slack_send_chat(msg) == false
        @pending.unshift msg
        break
      end
    end
  end

  def slack_send_chat(msg)
    self.discover_channel_id if !@channel_id

    data = {
      channel: @channel_id,
      text:    msg
    }

    response_data = slack_api(SLACK_POST_MESSAGEL_METHOD, SLACK_BOT_TOKEN, data, accept_notok=true)
    return response_data['ok']
  end

  def discover_channel_id
    data = self.slack_api(SLACK_CONVERSATIONS_LIST_METHOD, SLACK_BOT_TOKEN, {})
    channel = data['channels'].find { |channel| channel['name'] == SLACK_CHANNEL }
    @channel_id = channel['id']
    log :debug, "slack channel id #{@channel_id}"
  end

end
