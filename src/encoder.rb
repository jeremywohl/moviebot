#
# Encoding automata
#

class Encoder
  
  attr :queue  # for testing
  
  def initialize
    @queue = Queue.new
  end

  def self.start_async
    encoder = Encoder.new

    Thread.new do
      begin
        encoder.go
      rescue => e
        log :error, 'encoder died', exception: e
        SLACK.send_text_message("I (encoder) die!", poke_channel: true)
      end
    end

    return encoder
  end

  def go
    start_pending_encodes

    loop do
      encode(@queue.pop)
      break if $shutdown
    end
  end

  def encode(movie)
    if !File.exist?(movie.rip_fn)
      SLACK.send_text_message( %(Hmmm, #{File.basename(movie.rip_fn)} doesn't seem to exist anymore; skipping.), poke_channel: true )
      movie.change_state(:failed)
      return
    end

    encodes_left =
      case @queue.size
      when 0
        'no others queued, '
      else
        sprintf("%s left, ", pluralize(@queue.size, 'other', 'others'))
      end

    SLACK.send_text_message("Starting the encode of \"#{movie.name}\" [#{movie.track_name}] (#{encodes_left}with #{PLATFORM.free_space}G free space).")
    
    movie.set_encode_fn
    movie.change_state(:encoding)
    
    exit_code, result, timing = PLATFORM.encode(movie)
    log :debug, result

    if $shutdown
      log :info, "Encoder shutdown and cleanup..."
      File.delete(movie.encode_fn) if File.exist?(movie.encode_fn)
      movie.change_state(:ripped)  # return to ripped state for later encoding
      return
    end

    if exit_code > 0
      movie.change_state(:ripped)
      SLACK.send_text_message("There was an error while encoding \"#{movie.name}\"; please see the log.")
      return
    end

    SLACK.send_text_message("Finished encoding \"#{movie.name}\" [#{movie.track_name}] (took #{timing}).")
    
    log :info, "deleting #{movie.rip_fn}"
    FileUtils.remove_dir(movie.rip_dir)
    
    movie.done_fn = "#{DONE_ROOT}/#{movie.name}.m4v"
    if File.exist?(movie.done_fn)
      movie.done_fn = "#{DONE_ROOT}/#{movie.name}-#{SecureRandom.hex[0...5]}.m4v"
    end
    movie.save

    File.rename(movie.encode_fn, movie.done_fn)
    movie.change_state(:done)
  end
  
  def add_movie(m)
    @queue << m
  end

  # Enqueue ripped movies ready to encode, from a prior run.
  def start_pending_encodes
    Movie.where(state: 'ripped').each { |movie| self.add_movie(movie) }
  end

end
