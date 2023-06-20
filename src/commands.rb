#
# Slack-driven commands
#

class Commands

  VerboseStates = {
    'pending'  => 'waiting to be ripped',
    'ripping'  => 'now ripping',
    'ripped'   => 'waiting to be encoded',
    'encoding' => 'now encoding',
  }

  def initialize
    @commands = Hash[self.methods.grep(/_command$/).map { |m| [ m.to_s.gsub(/_command$/, ''), m ] }]
  end

  def huh?
    SLACK.send_text_message %(Huh? Try "#{SLACK_CHAT_NAME} help.")
  end
  
  def handle_msg(msg)
    verb, rest = msg.split(/\s+/, 2)
    verb.strip!
    rest.strip! if rest
    
    if @commands.has_key? verb
      begin
        self.send(@commands[verb], rest)
      rescue => e
        log :error, "slack command [#{verb}] failed", exception: e
      end
    else
      huh?
    end
  end

  def eject_command(rest)
    SLACK.send_text_message("Ejecting!")
    RIPPER.eject
  end
  
  def confirm_repeat_command(rest)
    RIPPER.confirm_repeat
  end
  
  def continue_ripping_command(rest)
    RIPPER.continue_ripping
  end

  # send Slack our current movie list
  def notify_movie_list
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    if files.empty?
      SLACK.send_text_message("There are no completed shows at the moment.")
    else
      msg = "Here are your completed shows:\n"
      files.each_with_index do |path, index|
        msg << "#{index+1}) #{File.basename(path, '.*')}\n"
      end
      SLACK.send_text_message(msg)
    end
  end

  def list_command(rest)
    notify_movie_list
  end
  
  def rename_command(rest)
    index, new_fn = rest.split(/ /, 2)
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    index = index.to_i
    
    if index > 0 && index <= files.length && new_fn && new_fn !~ /^\s+$/
      old_fn = File.basename(files[index - 1], '.*')
      File.rename("#{DONE_ROOT}/#{old_fn}.m4v", "#{DONE_ROOT}/#{new_fn}.m4v")
      SLACK.send_text_message("OK, I renamed \"#{old_fn}\" to \"#{new_fn}\".")
      notify_movie_list
    else
      huh?
    end
  end
  
  def archive_command(rest)
    # possibly removable media
    if !File.exists?(ARCHIVE_ROOT)
      SLACK.send_text_message("Hmm, I can't see the archive root #{ARCHIVE_ROOT}.", bang: true)
      return
    end

    fields  = rest.split
    target  = fields.shift
    indices = fields.map { |x| x.to_i }
    
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    
    if !ARCHIVE_TARGETS.keys.include?(target) || !indices.all? { |x| x > 0 && x <= files.length }
      huh?
    else
      indices.each do |index|
        MOVER.add_move(OpenStruct.new(source: files[index - 1], target: target))
        SLACK.send_text_message("OK, added \"#{File.basename(files[index - 1], '.*')}\" to my archive queue.")
      end
    end
  end
  
  def space_command(rest)
    SLACK.send_text_message("I have #{PLATFORM.free_space}G of free space!")
  end

  def what_command(rest)
    active = Movie.where(state: %w( pending ripping ripped encoding )).order(Sequel.desc(:id)).all

    if active.empty?
      status = 'Just sitting here. How about you?'
    else
      status = "What's in progress:\n"
      active.each do |movie|
        status += ">#{movie.name} [#{movie.track_name}] (#{VerboseStates[movie.state]})\n"
      end
    end

    SLACK.send_text_message(status)
  end

  def status_command(rest)
    self.what_command(rest)
  end

  def demo_command(rest)
    if !DEMO_MODE
      SLACK.send_text_message("Sorry, I wasn't started in demo mode.", bang: true)
      return
    else
      PLATFORM.set_disc_is_present
    end
  end

  def help_command(rest)
    msg  = "Here are common things you can say to me:\n"
    msg << ">#{SLACK_CHAT_NAME} archive {#{ARCHIVE_TARGETS.keys.join(',')}} 1 [2 3 4]\n"
    msg << ">#{SLACK_CHAT_NAME} eject\n"
    msg << ">#{SLACK_CHAT_NAME} list\n"
    msg << ">#{SLACK_CHAT_NAME} rip 1[,2,3,4]\n"
    msg << ">#{SLACK_CHAT_NAME} rename n Some new name (for n, see list)\n"
    msg << ">#{SLACK_CHAT_NAME} space\n"
    msg << ">#{SLACK_CHAT_NAME} status (or what)\n\n"
    msg << "Here are my other commands:\n"
    msg << ">#{SLACK_CHAT_NAME} confirm_repeat\n"
    msg << ">#{SLACK_CHAT_NAME} continue_ripping\n"
    msg << ">#{SLACK_CHAT_NAME} demo\n"

    SLACK.send_text_message(msg)
  end
  
end

COMMANDS = Commands.new
