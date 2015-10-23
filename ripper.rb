#
# Disc automata
#

MKV_LIST = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot info disc:0"
MKV_RIP  = "#{MAKEMKV_BIN} --minlength=%{minlength} --robot mkv disc:0"

class DiscSpinner

  def initialize
    @states   = Hash[self.methods.grep(/_state$/).map   { |m| [ m.to_s.gsub(/_state$/,   ''), m ] }]
    @tracks   = []
    @prevsig  = ''
    @currsig  = '<empty>'
    
    @confirm_repeat = false

    set_state :idle
  end
  
  #
  # utils
  #
  
  def what_device
    `drutil status`.lines.grep(/Name:/).first[/Name:\s+(.+)$/, 1]
  end
  
  def disc_present
    `drutil status`.lines.grep(/No Media/).empty?
  end

  def fetch_tracks
    @tracks = []
    disc = ''
    time = ''
    size = 0

    mkv_cmd = MKV_LIST % { minlength: MKV_SCAN_MINLENGTH * 60 }
    `#{mkv_cmd}`.lines.each do |line|
      puts line
      case line
      when /MSG:5073,260,0,"Your temporary key has expired/
        notify("Hmm, your MakeMKV key is expired.  Please update in the MakeMKV app, separately.")
        eject
        return
      when /MSG:5055,0,0,"Evaluation period has expired/
        notify("Hmm, your MakeMKV evaluation period is expired.  Please update the MakeMKV app.")
        eject
        return
      when /^CINFO:30,0,\"(.+)\"$/
        disc  = $1
      when /^TINFO:(\d+),(\d+),\d+,(.+)$/
        title = $1
        code  = $2.to_i
        value = $3.tr('"', '')
        
        time = value if code == 9
        size = value[/([\.\d]+)/, 1] if code == 10
        if code == 27
          o = OpenStruct.new(disc: disc, title: title, name: value, time: time, size: size)
          t = time.split(':')
          o.time_in_minutes = t[0].to_i * 60 + t[1].to_i
          @tracks << o
        end
      end
    end
    
    if !@tracks.empty?
      @prevsig = @currsig
      @currsig = make_disc_signature
    end
  end
  
  def make_disc_signature
    @tracks.first.disc + '::' + @tracks.map(&:title).join(',,')
  end
  
  #
  # external
  #

  def eject
    set_state :ejecting
    sleep 20
    `drutil eject`
    sleep 20
    set_state :idle
  end
  
  def add_tracks(tracks)
    tracks.each { |t| @queue << t }
    set_state :ripping
  end
  
  def tracks
    @tracks
  end
  
  def confirm_repeat
    @confirm_repeat = true
    set_state :present
  end

  #
  # main loop
  #
  
  def go
    loop do
      self.send(@state)
    end
  end
  
  #
  # states (idle, present, asking, ripping)
  #
  
  def set_state(st)
    st = st.to_s
    if @states.has_key? st
      @state = @states[st]
    else
      raise "I don't have a state #{st}."
    end
  end
  
  def idle_state
    if disc_present
      set_state :present
      @queue = Queue.new
    else
      sleep 10
    end
  end
  
  def present_state
    notify("Ooh, a new disc!")
    
    fetch_tracks
    
    min_tracks = @tracks.select { |t| t.time_in_minutes > MKV_RIP_MINLENGTH }
    
    if @currsig == @prevsig && !@confirm_repeat
      notify("We're seeing the same disc again -- to combat eject problems, please tell me \"confirm_repeat\".", poke_channel: true)
      set_state :asking
    elsif @tracks.empty?
      notify("Hmm, I didn't find any show-length tracks on this disc -- ejecting!", poke_channel: true)
      eject
    elsif @tracks.length == 1 || min_tracks.length == 1
      track = min_tracks.first || @tracks.first
      msg = "There's only one show-length track, so I'm going to start ripping it now.\n"
      msg << "1: #{track.name} [#{track.time}, #{track.size}G]\n"
      notify(msg)
      @queue << track
      set_state :ripping
    else
      msg = "This disc contains the following tracks (of importance):\n"
      @tracks.each_with_index do |track, index|
        msg << "#{index+1}) #{track.name} [#{track.time}, #{track.size}G]\n"
      end
      msg << %(You can tell me to "rip 1[,2,3,..]" or "rip all" or "eject".)
      notify(msg, poke_channel: true)
      set_state :asking
    end
    
    @confirm_repeat = false
  end
  
  def asking_state
    sleep 1  # slow wait
  end
  
  # so a Slack command (different thread) doesn't conflict with :idle
  def ejecting_state
    sleep 1
  end
  
  def ripping_state
    fail = false
    
    while !@queue.empty?
      track   = @queue.pop
      mkv_dir = "#{RIPPING_ROOT}/#{SecureRandom.hex[0...5]}-#{File.basename(track.name, ".*")}"
      
      Dir.mkdir(mkv_dir)
      start = Time.now
      notify("Starting to rip \"#{track.name}\" (with #{free_space}G free space).")
      
      rip_cmd = "#{MKV_RIP % { minlength: MKV_SCAN_MINLENGTH * 60 }} #{track.title} \"#{mkv_dir}\""
      puts rip_cmd
      results = `#{rip_cmd}`
      puts results
      
      if results.lines.grep(/Copy complete/).first =~ /failed/
        notify("Sorry, the rip of \"#{track.name}\" failed (took #{format_time_diff(start)}).  Try cleaning the disc and refeeding?")
        Dir.rmdir(mkv_dir)

        fail = true
        break
      else
        notify("Finished ripping of \"#{track.name}\" (took #{format_time_diff(start)}).")
      
        movie = OpenStruct.new(mkv_path: "#{mkv_dir}/#{track.name}", base: File.basename(track.name, ".*"))
        MP4_SPINNER.add_movie(movie)
      end
    end

    if fail
      notify("Ejecting.", poke_channel: true)  # for tone
    else
      notify("Ejecting!  Feed me another!", poke_channel: true)
    end
    
    eject
  end
  
end

DISC_SPINNER = DiscSpinner.new
Thread.new do
  begin
    DISC_SPINNER.go
  rescue
    notify("I (discspinner) die!", poke_channel: true)
    puts $!, $@
  end
end
