#
# Disc automata
#

TRACK_LENGTH   = 9
TRACK_SIZE     = 10
TRACK_FILENAME = 27

MAX_TRACK_LIST = 30

class Ripper

  def initialize
    @states   = Hash[self.methods.grep(/_state$/).map   { |m| [ m.to_s.gsub(/_state$/,   ''), m ] }]
    @tracks   = []   # MakeMKV track data structs
    @queue    = nil  # Movie objects, to be ripped
    @prevsig  = ''
    @currsig  = '<empty>'

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
        notify("I (ripper) die!", poke_channel: true)
      end
    end

    return ripper
  end

  #
  # utils
  #

  def fetch_tracks
    @tracks = []
    disc = ''
    time = ''
    size = 0

    PLATFORM.disc_list.lines.each do |line|
      log :debug, line

      case line

      # failure cases
      when /MSG:5073,260,0,"Your temporary key has expired/
        notify("Hmm, your MakeMKV key is expired.  Please update in the MakeMKV app, separately.")
        eject
        return false
      when /MSG:5055,0,0,"Evaluation period has expired/, /MSG:5021,260,1,"This application version is too old./
        notify("Hmm, your MakeMKV evaluation period is expired.  Please update the MakeMKV app.")
        eject
        return false

      # disc name
      when /^CINFO:30,0,\"(.+)\"$/
        disc  = $1

      # track entry
      when /^TINFO:(\d+),(\d+),\d+,(.+)$/
        id    = $1
        code  = $2.to_i
        value = $3.tr('"', '')

        case code
        when TRACK_LENGTH
          time = value
        when TRACK_SIZE
          size = value.gsub(/\s+/, '').gsub(/B$/, '')
        when TRACK_FILENAME
          o = OpenStruct.new(disc: disc, id: id, name: value, time: time, size: size)
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

    true
  end

  def make_disc_signature
    @tracks.first.disc + '::' + @tracks.map(&:id).join(',,')
  end

  #
  # called via Slack commands
  #

  def eject
    set_state :ejecting
    PLATFORM.eject
    set_state :idle
  end

  # options: { all: true/false, tracks: [ 1,2,5,... ] }
  # note: tracks is 0-based
  def add_tracks(options)
    _tracks = options[:all] ? 0...@tracks.length : options[:tracks]

    _tracks.each do |track_index|
      next if track_index >= @tracks.length  # if user asks for non-existent
      @queue << Movie.new.set_from_track(@tracks[track_index]).save
    end

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
    if PLATFORM.disc_present?
      set_state :present
      @queue = Queue.new
    else
      PLATFORM.sleep_idle
    end
  end

  def present_state
    notify("Ooh, a new disc!")

    return if !fetch_tracks

    min_tracks = @tracks.select { |t| t.time_in_minutes > MKV_RIP_MINLENGTH }

    if @currsig == @prevsig && !@confirm_repeat
      notify("We're seeing the same disc again (computer asleep/locked?) -- if you'd like to repeat it, please tell me \"confirm_repeat\".", poke_channel: true)
      set_state :asking
    elsif @tracks.empty?
      notify("Hmm, I didn't find any show-length tracks on this disc -- ejecting!", poke_channel: true)
      eject
    elsif @tracks.length == 1 || min_tracks.length == 1
      track = min_tracks.first || @tracks.first
      msg = "There's only one show-length track, so I'm going to start ripping it now.\n"
      msg << "1: #{track.name} [#{track.time}, #{track.size}]\n"
      notify(msg)
      @queue << Movie.new.set_from_track(track).save
      set_state :ripping
    else
      msg = "This disc contains the following tracks:\n"
      @tracks.first(MAX_TRACK_LIST).each_with_index do |track_, index|
        msg << "#{index+1}) #{track_.name} [#{track_.time}, #{track_.size}]\n"
      end
      if @tracks.size > MAX_TRACK_LIST
        msg << ".. list too long, possible copy protection & playlist obfuscation ..\n"
      end
      msg << %(You can tell me to "rip 1[,2,3,..]" or "rip all" or "eject".)
      notify(msg, poke_channel: true)
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
    fail = false

    while !@queue.empty?
      movie = @queue.pop
      movie.set_rip_paths
      movie.change_state(:ripping)

      log :info, movie.inspect
      Dir.mkdir(movie.rip_dir)
      notify("Starting to rip \"#{movie.name}\" [#{movie.track_name}] (with #{PLATFORM.free_space}G free space).")

      results, timing = PLATFORM.disc_rip(movie)
      log :debug, results

      if results.lines.grep(/Copy complete/).first =~ /failed/
        notify("Sorry, the rip of \"#{movie.name}\" [#{movie.track_name}] failed (took #{timing}).  Try cleaning the disc and refeeding?")
        Dir.rmdir(movie.rip_dir)

        movie.change_state(:failed)
        fail = true
        break
      else
        notify("Finished ripping \"#{movie.name}\" [#{movie.track_name}] (took #{timing}).")
        movie.change_state(:ripped)
        ENCODER.add_movie(movie)
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
