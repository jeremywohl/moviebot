#
# slack robot
#

class Slack

  SLACK_API_PREFIX_URL            = 'https://slack.com/api/'
  SLACK_SOCKET_MODE_METHOD        = 'apps.connections.open'
  SLACK_CONVERSATIONS_LIST_METHOD = 'conversations.list'
  SLACK_POST_MESSAGEL_METHOD      = 'chat.postMessage'

  MAX_SEND_CHARS  = 4_000

  def initialize
    @mutex       = Mutex.new
    @pending     = Concurrent::Array.new
    @ws_ready    = false                  # we are connected and ready to chat
    @ws_refresh  = false                  # the current ws close sequence is a requested Slack socket refresh
    @msg_id      = 1                      # correlate echo'd Slack messages with unique id
    @shutdown    = false
    @channel_id  = nil                    # the movies channel id
  end

  def go
    0.step do |i|
      begin
        self.fetch_slack_websocket
        self.loop_websocket(i)
      rescue => e
        puts "Error during processing: #{$!}"
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        # ignore failures
      end

      break if @shutdown
      sleep 1  # TODO: add backoff
    end
  end

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

  def events-server
    class EventsApp
      def call(env)
        [200, { 'Content-Type' => 'text/plain' }, ['Hello from embedded Puma instance!']]
      end
    end

    server = Puma::Single.new(EventsApp.new)
    server.port = 8050
    server.run
    log :info 'after server.run'
  end
  
  # Get real-time API endpoint (and other details)
  def fetch_slack_websocket
    data = self.slack_api(SLACK_SOCKET_MODE_METHOD, SLACK_APP_TOKEN, {})
    @ws_uri = URI(data['url'])  # for testing connection refresh requests: + '&debug_reconnects=true')
  end

  def loop_websocket(socket_count)
    # Queue start messages to user before other asynchronous activities occur (e.g. disc discovery).
    if socket_count == 0
      self.notify('Waking up.')
    else
      self.notify('Oops -- reconnected to Slack.  Sorry if we missed anything.')
    end

    tcp = TCPSocket.new(@ws_uri.host, 443)
    @tls = OpenSSL::SSL::SSLSocket.new(tcp)
    @tls.connect

    @mutex.synchronize { @wsrefresh = false }
    @driver = WebSocket::Driver.client(self)

    @driver.on :message, -> (event) {
      log :debug, "websocket message: #{event.data}"
      data = JSON.parse(event.data)

      case data['type']
      when 'hello'
       # intro message / noop

      when 'disconnect'
        # Slack would like us to reconnect
        log :debug, "refreshing slack websocket, by request"
        @mutex.synchronize { @wsrefresh = true }
        @driver.close

      when 'slash_commands'
        self.handle_message(data['payload']['text'])
        @driver.text("{ 'envelope_id': data['envelope_id'], 'response_type': 'in_channel', 'text': 'say something' }")

      else
        log :info, "a message we don't handle of type '#{data['type']}'"
        # we generically confirm receipt by echoing envelope_id
        if data.has_key?('envelope_id')
          @driver.text( { 'envelope_id': data['envelope_id'], }.to_json )
        end

      end
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
          unless @wsrefresh
            log :info, "slack has closed our connection", exception: e
          end
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

  def handle_message(command)
    log :info, "slack said: [#{command}]"
    Thread.new { COMMANDS.handle_msg(command) }
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
    self.send_pending
  end

  def send_pending
    @mutex.synchronize do
      return if !@wsready

      while (msg = @pending.shift)
        if self.slack_send_chat(msg) == false
          @pending.unshift msg
          break
        end

        @msg_id += 1
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
