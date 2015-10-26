#
# slack robot
#

# TODO: connection restarts

class Slack

  RTM_START_URL = "https://slack.com/api/rtm.start?token=#{SLACK_API_TOKEN}&no_unreads=true&simple_latest=true"

  def initialize
    @mutex   = Mutex.new
    @wsready = Concurrent::IVar.new

    @msg_id = 1  # correlate echo'd Slack messages with unique id
  end

  def go
    fetch_slack_endpoint
    loop_websocket
  end

  # Get real-time API endpoint (and other details)
  def fetch_slack_endpoint
    response = Net::HTTP.get_response(URI.parse(RTM_START_URL))

    if response.code != '200'
      log :error, "Sorry, problem connecting to Slack.  Here's what they said."
      log :error, response.body
      exit 1
    end

    data = JSON.parse(response.body) rescue {}

    if data['ok'] != true
      log :error, "Sorry, problem connecting to Slack.  Here's the error: #{data['error']}.  We die."
      log :error, data
      exit 1
    end

    channels = data['channels'].select { |c| c['name'] == SLACK_CHANNEL }
    if channels.empty?
      log :error, "Sorry, we can't find channel #{SLACK_CHANNEL}.  We die."
      exit 1
    end

    @channel_id = channels.first['id']
    @ws_uri     = URI(data['url'])
  end

  def loop_websocket
    tcp = TCPSocket.new(@ws_uri.host, 443)
    @tls = OpenSSL::SSL::SSLSocket.new(tcp)
    @tls.connect

    @driver = WebSocket::Driver.client(self)

    @driver.on :message, -> (event) {
      data = JSON.parse(event.data)
      self.handle_message(data['text']) if data['type'] == 'message'
    }

    if !@driver.start
      log :error, "failed to make websocket handshake"
      exit 1
    end

    @read_thread = Thread.new do
      loop do
        begin
          @driver.parse(@tls.readpartial(16 * 1024))  # Slack docs say 16K max msgs
        rescue EOFError
          log :info, "slack has closed our connection"
          break
        rescue => e
          log :error, 'failure in Slack read loop', exception: e
          break
        end
      end
    end
    
    @wsready.set(true)
    self.notify('Waking up.')
    
    @read_thread.join
  end

  def closeup
    @read_thread.kill
  end

  def handle_message(text)
    if text =~ /\A#{SLACK_CHAT_NAME} /
      command = text[SLACK_CHAT_NAME.length+1..-1]
      log :info, "slack said: [#{command}]"
      Thread.new { COMMANDS.handle_msg(command) }
    end
  end

  # used by websocket-driver
  def url
    @ws_uri.to_s
  end

  # used by websocket-driver
  def write(s)
    @tls.write(s)
  end

  # tell Slack channel something; accepts /poke_channel: true/ to alert the channel.
  def notify(msg, opts={})
    if opts[:poke_channel]
      if msg.lines.size > 1
        msg << "\n" if msg[-1] != "\n"
        msg << "<!channel> (see above)"
      else
        msg = "<!channel> " << msg
      end
    end

    @mutex.synchronize do
      @wsready.wait

      out = { id: @msg_id, type: 'message', channel: @channel_id, text: msg }
      @driver.text(out.to_json)
      @msg_id += 1
    end
  end

end
