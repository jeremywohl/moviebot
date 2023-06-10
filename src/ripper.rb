#
# Disc automata
#

class Ripper

  # MakeMKV CINFO/TINFO record identifiers
  #  see https://github.com/automatic-ripping-machine/automatic-ripping-machine/wiki/MakeMKV-Codes
  TRACK_LENGTH   = 9   # h:m:s
  TRACK_SIZE     = 11  # Note: the formatted '10' record uses incorrect powers-of-2 GB, so use this in bytes.
  TRACK_FILENAME = 27
  DISC_NAME      = 30

  MAX_TRACK_LIST = 23  # BlockKit restricts lists to 25 items (23 + all & eject); seems unlikely we'll need more.

  def initialize
    @states    = Hash[self.methods.grep(/_state$/).map   { |m| [ m.to_s.gsub(/_state$/,   ''), m ] }]
    @disc_name = ''   # Current disc, if any
    @tracks    = []   # MakeMKV track data structs
    @queue     = nil  # Movie objects, to be ripped
    @prevsig   = ''
    @currsig   = '<empty>'
    @ejected   = true

    @confirm_repeat = false

    set_state :idle
  end

  def self.start_async
    ripper= Ripper.new

    Thread.new do
      begin
        ripper.go
      rescue => e
        log :error, 'ripper died', exception: e
        SLACK.send_text_message("I (ripper) die!", poke_channel: true)
      end
    end

    return ripper
  end

  def go
    cleanup_abandoned_rips

    loop do
      self.send(@state)
      break if $shutdown
    end
  end

  #
  # utils
  #

  def fetch_tracks
    @tracks = []
    time = ''
    size = 0

    #File.read(File.join(File.expand_path(File.dirname(__FILE__)), 'makemkv.output')).lines.each do |line|
    disc_list = PLATFORM.disc_list
    
    return false if $shutdown
    
    fetch_log = debug_logfile(label: 'track-list', description: 'MakeMKV track listing')
    fetch_log.write disc_list
    fetch_log.close

    disc_list.lines.each do |line|
      case line

      # failure cases
      when /MSG:5073,260,0,"Your temporary key has expired/
        SLACK.send_text_message("Hmm, your MakeMKV key is expired.  Please update in the MakeMKV app, separately.")
        eject
        return false
      when /MSG:5055,0,0,"Evaluation period has expired/, /MSG:5021,260,1,"This application version is too old./
        SLACK.send_text_message("Hmm, your MakeMKV evaluation period is expired.  Please update the MakeMKV app.")
        eject
        return false

      # disc entries, we just take the name
      when /^CINFO:#{DISC_NAME},0,\"(.+)\"$/
        @disc_name = $1

      # track entries
      when /^TINFO:(\d+),(\d+),\d+,(.+)$/
        id    = $1.to_i
        code  = $2.to_i
        value = $3.tr('"', '')

        case code
        when TRACK_LENGTH
          t = value.split(':')  # h:m:s
          if t.size == 2
            time = t[1].to_i * 60 + t[2].to_i
          elsif t.size == 3
            time = t[0].to_i * 3600 + t[1].to_i * 60 + t[2].to_i
          else
            log :error, "not built to parse time like [#{value}]; please file a bug with this line"
            time = 0
          end
        when TRACK_SIZE
          size = value.to_i
        when TRACK_FILENAME
          o = OpenStruct.new(disc_name: @disc_name, id: id, name: value, time: time, size: size, picked: false)
          @tracks << o
        end

      end
    end

    if !@tracks.empty?
      @prevsig = @currsig
      @currsig = make_disc_signature
    end

    true
  end

  def make_disc_signature
    @tracks.first.disc_name + '::' + @tracks.map(&:id).join(',,')
  end

  def cleanup_abandoned_rips
    Movie.where(state: [ 'pending', 'ripping' ]).each do |movie|
      movie.state = 'abandoned'
      movie.save

      if !movie.rip_dir.nil?
        log :info, "Removing abandoned rip directory [#{movie.rip_dir}]"
        FileUtils.remove_dir(movie.rip_dir)
      end
    end
  end

  # Send Slack a block kit list of tracks and track selection buttons
  # options: poke_channel: t/f, from_action: <a selection action>
  def notify_track_list(opts = {})
    vars = {
      disc_name:       @disc_name,
      tracks:          @tracks.first(MAX_TRACK_LIST),
      track_indexes:   @tracks.select { |t| t.picked }.map { |t| t.id+1 },
      copy_protection: @tracks.size > MAX_TRACK_LIST,
      ripping_any:     @tracks.any? { |t| t.picked },
      ripping_all:     @tracks.all? { |t| t.picked },
      ejected:         @ejected,
    }

    rendered = render_template('slack-track-list.tmpl', vars)
    SLACK.send_block_kit_message(
      rendered,
      "Choose which tracks you'd like to rip",
      poke_channel: true,
      from_action: opts[:from_action]
    )
  end

  #
  # commands or actions, invoked via Slack
  #

  def eject
    set_state :ejecting

    if PLATFORM.drive_locked?
      # TODO: upgrade to include BlockKit Eject button
      SLACK.send_text_message("I'd like to eject the disc, but the drive is locked (computer asleep?); tell me \"movie eject\" when you wake it up.")
    else
      PLATFORM.eject
      @ejected = true
      set_state :idle
    end
  end

  # handle track list action buttons
  def track_list_pick(action)
    set_ripping = false

    if action.value['eject']
      self.eject
    else
      indexes = action.value['all_tracks'] ? 0...@tracks.length : [ action.value['one_track'] ]

      indexes.each do |index|
        if !@tracks[index].picked  # skip tracks already picked (user can select one-by-one over many actions)
          @tracks[index].picked = true
          set_ripping = true
          @queue << Movie.new.set_from_track(@tracks[index]).save
        end
      end
    end

    notify_track_list(from_action: action)
    set_state :ripping if set_ripping
  end

  def confirm_repeat
    @confirm_repeat = true
    set_state :present
  end

  #
  # state logic (idle, present, asking, ripping, ejecting)
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
    if PLATFORM.disc_present?
      set_state :present
      @ejected = false
      @queue = Queue.new
    else
      PLATFORM.sleep_idle
    end
  end

  def present_state
    SLACK.send_text_message("Ooh, a new disc!")

    return if !fetch_tracks

    min_tracks = @tracks.select { |t| ( t.time / 60 ) > MKV_RIP_MINLENGTH }

    if @currsig == @prevsig && !@confirm_repeat
      SLACK.send_text_message("We're seeing the same *#{@disc_name}* disc again -- if you'd like to repeat it, please tell me \"confirm_repeat\".", poke_channel: true)
      set_state :asking
    elsif @tracks.empty?
      SLACK.send_text_message("Hmm, I didn't find any show-length tracks on disc *#{@disc_name}* -- ejecting!", poke_channel: true)
      eject
    elsif @tracks.length == 1 || min_tracks.length == 1
      track = min_tracks.first || @tracks.first
      msg = "There's only one show-length track on *#{@disc_name}*, so I'm going to start ripping it now.\n"
      msg << "1: #{track.name} [#{format_time(track.time)}, #{format_size(track.size)}]\n"
      SLACK.send_text_message(msg)
      @queue << Movie.new.set_from_track(track).save
      set_state :ripping
    else
      notify_track_list
      set_state :asking
    end

    @confirm_repeat = false
  end

  def asking_state
    PLATFORM.sleep_slow_wait
  end

  # so a Slack command (different thread) doesn't conflict with :idle
  def ejecting_state
    PLATFORM.sleep_slow_wait
  end

  def ripping_state
    had_fail = false

    while !@queue.empty?
      movie = @queue.pop
      movie.set_rip_paths
      movie.change_state(:ripping)

      Dir.mkdir(movie.rip_dir)
      SLACK.send_text_message("Starting to rip \"#{movie.name}\" [#{movie.track_name}] (with #{PLATFORM.free_space}G free space).")

      rip_start_time = Time.now
      exit_code, results, timing = PLATFORM.disc_rip(movie)

      rip_log = debug_logfile(movie_id: movie.id, label: 'rip', description: 'MakeMKV rip log')
      rip_log.write results
      rip_log.close

      if $shutdown
        log :info, "Ripper shutdown and cleanup..."
        cleanup_abandoned_rips
        return
      end

      if exit_code > 0 || results.lines.grep(/Copy complete/).first =~ /failed/
        SLACK.send_text_message("Sorry, the rip of \"#{movie.name}\" [#{movie.track_name}] failed (took #{timing}).  Try cleaning the disc and refeeding?")
        Dir.rmdir(movie.rip_dir)

        movie.change_state(:failed)
        had_fail = true
      else
        SLACK.send_text_message("Finished ripping \"#{movie.name}\" [#{movie.track_name}] (took #{timing}).")
        movie.change_state(:ripped)
        movie.rip_time = Time.now - rip_start_time
        ENCODER.add_movie(movie)
      end
    end

    if had_fail
      SLACK.send_text_message("Ejecting. Try cleaning the disc, for those failed tracks?", poke_channel: true)  # for tone
    else
      SLACK.send_text_message("Ejecting!  Feed me another!", poke_channel: true)
    end

    eject
  end

end
