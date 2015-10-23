# movie volume free space in gibabytes
def free_space
  `df -H #{MOVIES_ROOT}`.lines[-1].split[3].to_i
end

# e.g. 3s or 15m:20s or 2h:21m
def format_time_diff(tstart)
  diff = Time.now - tstart
  if diff < 60
    sprintf "%ds", diff
  elsif diff < 60 * 60
    sprintf "%dm:%ds", diff / 60, diff % 60
  else
    sprintf "%dh:%dm", diff / (60 * 60), diff % (60 * 60) / 60
  end
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

  SLACK.message channel: SLACK_CHANNEL_ID, text: msg
end
