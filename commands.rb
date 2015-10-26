#
# Slack-driven commands
#

class Commands

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
      self.send(@commands[cmd], rest)
    else
      huh?
    end
  end
  
  def eject_command(rest)
    notify("Ejecting!")
    DISC_SPINNER.eject
  end
  
  def rip_command(rest)
    if rest == 'all'
      DISC_SPINNER.add_tracks(DISC_SPINNER.tracks)
    elsif rest =~ /[\d,]+/
      toq = []
      rest.split(',').each do |digits|
        next if digits !~ /\d+/
        next if digits.to_i > DISC_SPINNER.tracks.length
        toq << DISC_SPINNER.tracks[digits.to_i - 1]
      end
      DISC_SPINNER.add_tracks(toq)
    end
  end
  
  def confirm_repeat_command(rest)
    DISC_SPINNER.confirm_repeat
  end
  
  def encode_command(rest)
    found = false
    if rest =~ /^\w{5}$/ && !Dir["#{RIPPING_ROOT}/#{rest}-*"].empty?
      mkv = Dir["#{RIPPING_ROOT}/#{rest}-*/*.mkv"].first
      if mkv
        movie = OpenStruct.new(mkv_path: mkv, base: File.basename(mkv, ".*"))
        MP4_SPINNER.add_movie(movie)
        notify("OK, added \"#{File.basename(mkv)}\" to my encode queue.")
        found = true
      end
    end
    if !found
      notify("Hmm, I couldn't find anything like that.")
    end
  end
  
  # send Slack our current movie list
  def notify_movie_list
    files = Dir["#{DONE_ROOT}/*.m4v"].sort
    if files.empty?
      notify("There are no completed shows at the mo.")
    else
      msg = "Here are completed shows:\n"
      files.each_with_index do |path, index|
        msg << "#{index+1}) #{File.basename(path, '.*')}\n"
      end
      notify(msg)
    end
  end

  def list_command(rest)
    notify_movie_list
  end
  
  def normalize_command(rest)
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
    
    if !TARGETS.keys.include?(target) || !indices.all? { |x| x > 0 && x <= files.length }
      huh?
    else
      indices.each do |index|
        MOVER.add_move(OpenStruct.new(source: files[index - 1], target: target))
        notify("OK, added \"#{File.basename(files[index - 1], '.*')}\" to my archive queue.")
      end
    end
  end
  
  def space_command(rest)
    notify("I have #{free_space}G of free space!")
  end
  
  def help_command(rest)
    msg  = "Here are common things you can say to me:\n"
    msg << ">#{SLACK_CHAT_NAME} archive {#{TARGETS.keys.join(',')}} 1 [2 3 4]\n"
    msg << ">#{SLACK_CHAT_NAME} rip 1[,2,3,4]"
    msg << ">#{SLACK_CHAT_NAME} list\n"
    msg << ">#{SLACK_CHAT_NAME} normalize n (for n, see list)\n"
    msg << ">#{SLACK_CHAT_NAME} rename n Some new name (for n, see list)\n"
    msg << ">#{SLACK_CHAT_NAME} space\n\n"
    msg << "Here are my other commands:\n"
    msg << ">#{SLACK_CHAT_NAME} confirm_repeat\n"
    msg << ">#{SLACK_CHAT_NAME} eject\n"
    msg << ">#{SLACK_CHAT_NAME} encode abcde (where abcde is an existing folder code)\n"

    notify(msg)
  end
  
end

COMMANDS = Commands.new
