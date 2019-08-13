#
# slack robot
#

class Slack

  RTM_START_URL  = "https://slack.com/api/rtm.start?token=#{SLACK_API_TOKEN}&no_unreads=true&simple_latest=true"
  MAX_SEND_CHARS = 4_000

  def initialize
    @mutex    = Mutex.new
    @pending  = Concurrent::Array.new
    @wsready  = false
    @msg_id   = 1  # correlate echo'd Slack messages with unique id
    @shutdown = false
  end

  def go
    0.step do |i|
      begin
        fetch_slack_endpoint
        loop_websocket(i)
      rescue
        # ignore failures
      end

      break if @shutdown
      sleep 1  # TODO: add backoff
    end
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

  def loop_websocket(socket_count)
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
        rescue EOFError => e
          log :info, "slack has closed our connection", exception: e
          break
        rescue => e
          log :error, 'failure in Slack read loop', exception: e
          break
        end
      end
    end

    ws_keepalive = Concurrent::TimerTask.new(execution_interval: 30) { self.keepalive }
    ws_keepalive.execute

    @mutex.synchronize { @wsready = true }

    self.send_pending

    if socket_count == 0
      self.notify('Waking up.')
    else
      self.notify('Oops -- reconnected to Slack.  Sorry if we missed anything.')
    end

    @read_thread.join

    @mutex.synchronize { @wsready = false }
    ws_keepalive.shutdown
  end

  def closeup
    Thread.new { SLACK.notify('Goodbye.') }
    sleep 1

    @shutdown = true
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

  def keepalive
    @mutex.synchronize do
      @driver.ping
    end
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
    send_pending
  end

  def send_pending
    @mutex.synchronize do
      return if !@wsready

      while (msg = @pending.shift)
        out = { id: @msg_id, type: 'message', channel: @channel_id, text: msg }

        if @driver.text(out.to_json) == false
          @pending.unshift msg
          break
        end

        @msg_id += 1
      end
    end
  end

end
