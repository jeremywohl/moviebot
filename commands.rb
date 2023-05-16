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
    notify %(Huh? Try "#{SLACK_CHAT_NAME} help.")
  end
  
  def handle_msg(msg)
    cmd, rest = msg.split(/\s+/, 2)
    cmd.strip!
    rest.strip! if rest
    
    if @commands.has_key? cmd
      begin
        self.send(@commands[cmd], rest)
      rescue => e
        log :error, "slack command [#{cmd}] failed", exception: e
      end
    else
      huh?
    end
  end
  
  def eject_command(rest)
    notify("Ejecting!")
    RIPPER.eject
  end
  
  def rip_command(rest)
    if rest == 'all'
      RIPPER.add_tracks(all: true)
    elsif rest =~ /[\d,]+/
      toq = []
      rest.split(/,\s*/).each do |digits|
        next if digits !~ /\d+/
        toq << digits.to_i - 1  # add as 0-based
      end
      RIPPER.add_tracks(tracks: toq)
    end
  end
  
  def confirm_repeat_command(rest)
    RIPPER.confirm_repeat
  end
  
  # send Slack our current movie list
  def notify_movie_list
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    if files.empty?
      notify("There are no completed shows at the moment.")
    else
      msg = "Here are your completed shows:\n"
      files.each_with_index do |path, index|
        msg << "#{index+1}) #{File.basename(path, '.*')}\n"
      end
      notify(msg)
    end
  end

  def list_command(rest)
    notify_movie_list
  end
  
  def title_command(rest)
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    
    if rest == 'all'
      indices = files.each_with_index.map { |fn,i| i + 1 }
    else
      indices = rest.split.map { |s| s.to_i }
    end
    
    indices.each do |index|
      if index > 0 && index <= files.length
        old_fn = File.basename(files[index - 1], '.*')
        new_fn = title_case_fn(clean_fn(old_fn))
        File.rename("#{DONE_ROOT}/#{old_fn}.m4v", "#{DONE_ROOT}/#{new_fn}.m4v")
        notify("OK, I renamed \"#{old_fn}\" to \"#{new_fn}\".")
      else
        notify "Sorry, #{index} is not in my list."
      end
    end
    notify_movie_list
  end
  
  def rename_command(rest)
    index, new_fn = rest.split(/ /, 2)
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    index = index.to_i
    
    if index > 0 && index <= files.length && new_fn && new_fn !~ /^\s+$/
      old_fn = File.basename(files[index - 1], '.*')
      File.rename("#{DONE_ROOT}/#{old_fn}.m4v", "#{DONE_ROOT}/#{new_fn}.m4v")
      notify("OK, I renamed \"#{old_fn}\" to \"#{new_fn}\".")
      notify_movie_list
    else
      huh?
    end
  end
  
  def archive_command(rest)
    # possibly removable media
    if !File.exists?(ARCHIVE_ROOT)
      notify("Hmm, I can't see the archive root #{ARCHIVE_ROOT}.")
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
        notify("OK, added \"#{File.basename(files[index - 1], '.*')}\" to my archive queue.")
      end
    end
  end
  
  def space_command(rest)
    notify("I have #{PLATFORM.free_space}G of free space!")
  end

  def what_command(rest)
    active = Movie.where(state: %w( pending ripping ripped encoding )).order(Sequel.asc(:id)).all

    if active.empty?
      status = 'Just sitting here. How about you?'
    else
      status = "Here is what's in progress:\n"
      active.each do |movie|
        status += "#{movie.name} [#{movie.track_name}] (#{VerboseStates[movie.state]})\n"
      end
    end

    notify(status)
  end

  def status_command(rest)
    self.what_command(rest)
  end
  
  def help_command(rest)
    msg  = "Here are common things you can say to me:\n"
    msg << ">#{SLACK_CHAT_NAME} archive {#{ARCHIVE_TARGETS.keys.join(',')}} 1 [2 3 4]\n"
    msg << ">#{SLACK_CHAT_NAME} rip 1[,2,3,4]\n"
    msg << ">#{SLACK_CHAT_NAME} list\n"
    msg << ">#{SLACK_CHAT_NAME} title n (for n, see list)\n"
    msg << ">#{SLACK_CHAT_NAME} rename n Some new name (for n, see list)\n"
    msg << ">#{SLACK_CHAT_NAME} space\n"
    msg << ">#{SLACK_CHAT_NAME} status (or what)\n\n"
    msg << "Here are my other commands:\n"
    msg << ">#{SLACK_CHAT_NAME} confirm_repeat\n"
    msg << ">#{SLACK_CHAT_NAME} eject\n"

    notify(msg)
  end
  
end

COMMANDS = Commands.new
