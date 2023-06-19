#
# Slack robot
#
# We add event and action listeners, and make changes with the Web API.
# Events let us listen to "movie ..." commands, and actions occur at button
# presses or modal dialogs.
#
# The block_id of actions (see templates) contains a direct class & method
# call, for conveniently reaching any other subsystem. We encrypt these
# directives so we can trust they are opaque and unaltered.
#

# TODO: print/raise errors, regardless of debug setting
class WebrickLogger
  def <<(msg)
    #log :debug, "WEBRICK: #{msg}"
  end
end

class Slack

  SLACK_API_PREFIX_URL            = 'https://slack.com/api/'
  SLACK_CONVERSATIONS_LIST_METHOD = 'conversations.list'
  SLACK_POST_MESSAGE_METHOD       = 'chat.postMessage'
  SLACK_UPDATE_MESSAGE_METHOD     = 'chat.update'

  MAX_SEND_CHARS  = 4_000

  def initialize
    @pending     = Queue.new
    @channel_id  = nil  # the movies channel id
    @event_cache = Concurrent::Hash.new

    self.send_text_message('Waking up.')
  end

  def start_sync
    @events_server = self.start_events_server
    Thread.new { self.send_pending_messages }
    
    # block on server completion
    @events_server.start
  end

  # Receive events from Slack Events API.
  def start_events_server
    logger = WEBrick::Log.new(WebrickLogger.new)
    server = WEBrick::HTTPServer.new Port: SLACK_LISTEN_PORT, Host: SLACK_LISTEN_HOST,
      Logger: logger, AccessLog: [ [ logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT ] ]

    server.mount_proc SLACK_EVENT_URI do |request, response|
      data = JSON.parse(request.body)
      #log :debug, "slack event data [#{data.inspect}]"

      # server verification, echo challenge (we don't verify since we use a hidden URL)
      if data['type'] == 'url_verification'
        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = data['challenge']

        return
      end

      # all other events
      if @event_cache.has_key?(data['event_id'])
        # TODO: figure out when this can occur as a non-error state
        log :info, "Getting duplicate events, this is probably an error. Event id #{data['event_id']}."
      else
        event = data['event']

        if event['type'] == 'message' && !event.has_key?('subtype')
          wakeup_prefix, command = event['text'].split(' ', 2)

          if wakeup_prefix.downcase == SLACK_CHAT_NAME.downcase && command != nil && !command.empty?
            self.handle_message(command)
          end
        end

        @event_cache[data['event_id']] = 1
      end

      # acknowledge
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = ''
    end

    # send action data to the appropriate subsystem, ignore unverified messages
    server.mount_proc SLACK_ACTION_URI do |request, response|
      body = URI.decode_www_form(request.body)  # url-encoded body text
      data = JSON.parse(body[0][1])             # [ "payload", "json string" ]

      #log :debug, "slack interactive data [#{data.inspect}]"

      # TODO: this needed here?
      # server verification, echo challenge (we don't verify since we use a hidden URL)
      if data['type'] == 'url_verification'
        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = data['challenge']

        return
      end

      # handle action
      # TODO: ostensibly we can receive multiple actions -- when does this occur?
      _action = data['actions'].first
      action = OpenStruct.new(
        api_data:   data,
        message_ts: data['message']['ts'],
        target:     decrypt_hash(_action['block_id']),
        value:      decrypt_hash(_action['value']),
      )

      log :debug, "action object: message_ts: #{action.message_ts}, target: #{action.target.inspect}, value: #{action.value.inspect}"

      # if decryption succeeded, call target method; else, silently ignore this action
      if action.target != nil && action.value != nil
        Object.const_get(action.target['class'].upcase).send(action.target['method'], action)
      end

      # acknowledge
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = ''
    end

    return server
  end

  # Call Slack Web API. data must be a string.
  def slack_api(endpoint, token, data, accept_notok=false)
    headers = {
                'Content-type'  => 'application/json; charset=utf-8',
                'Authorization' => "Bearer #{token}"
              }

    response = Net::HTTP.post(URI.join(SLACK_API_PREFIX_URL, endpoint), data, headers)

    if response.code != '200'
      log :error, "Sorry, problem connecting to Slack.  Here's what they said."
      log :error, response.body
      exit 1 if accept_notok == false
    end

    response_data = JSON.parse(response.body) rescue {}

    if response_data['ok'] != true
      if response_data['error'] == 'invalid_json'
        log :error, "Sorry, Slack doesn't like our JSON. Here's a copy of what we tried to send."
        log :error, data
        @pending << { type: text, text: "Sorry, Slack didn't like some of our text, so there will be missing content. See the log for more details." }
        # carry on
      else
        log :error, "Sorry, problem connecting to Slack.  Here's the error: #{response_data['error']}.  We die."
        log :error, "[response] #{response.inspect}"
        log :error, "[response_data] #{response_data.inspect}"
        exit 1 if accept_notok == false
      end
    end

    return response_data
  end

  def closeup
    self.send_text_message('Goodbye.')
    @events_server.shutdown
    sleep 1
  end

  def handle_message(command)
    log :info, "slack said: [#{command}]"
    Thread.new { COMMANDS.handle_msg(command) }
  end

  # send Slack channel a simple text message; accepts /poke_channel: true/ to alert the channel.
  def send_text_message(msg, opts={})
    # observe Slack's message limit and truncate, if necessary
    msg = msg[0...MAX_SEND_CHARS-16]+"...truncating..." if msg.size >= MAX_SEND_CHARS

    @pending << { type: :text, text: msg }
    @pending << { type: :text, text: "<!channel> (see above)" } if opts[:poke_channel]
  end

  # send Slack channel a BlockKit message
  def send_block_kit_message(blocks, alternate_text, opts={})
    @pending << { type: :block, blocks: blocks, text: alternate_text, from_action: opts[:from_action] }
    @pending << { type: :text,  text: "<!channel> (see above)" } if opts[:poke_channel] && opts[:from_action].nil?
  end

  # send outgoing messages, perpetually
  def send_pending_messages
    begin
      while (msg = @pending.pop)
        self.discover_channel_id if !@channel_id

        data  = "{"
        data += %(  channel: "#{@channel_id}"                  )
        data += %(, ts:      "#{msg[:from_action].message_ts}" ) if msg[:from_action]
        data += %(, text:    #{msg[:text].to_json}             ) if msg[:text]
        data += %(, blocks:  #{msg[:blocks]}                   ) if msg[:blocks]
        data += "}"

        method = msg[:from_action] ? SLACK_UPDATE_MESSAGE_METHOD : SLACK_POST_MESSAGE_METHOD
        response_data = slack_api(method, SLACK_BOT_TOKEN, data, accept_notok=true)
    
        if response_data['ok'] == false
          # @pending.unshift msg
          break
        end

        sleep 0.5  # send up to 2 per second
      end
    rescue => e
      log :error, 'slack sender died', exception: e
    end
  end

  def discover_channel_id
    data = self.slack_api(SLACK_CONVERSATIONS_LIST_METHOD, SLACK_BOT_TOKEN, '{}')
    channel = data['channels'].find { |channel| channel['name'] == SLACK_CHANNEL }
    @channel_id = channel['id']
    log :debug, "slack channel id #{@channel_id}"
  end

end
