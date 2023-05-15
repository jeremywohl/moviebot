#
# Encoding automata
#

class Encoder
  
  attr :queue  # for testing
  
  def initialize
    @queue = Queue.new
    @current_encode = nil
  end

  def self.start_async
    encoder = Encoder.new

    Thread.new do
      begin
        encoder.go
      rescue => e
        log :error, 'encoder died', exception: e
        notify("I (encoder) die!", poke_channel: true)
      end
    end

    return encoder
  end

  def go
    start_pending_encodes

    loop do
      movie = @queue.pop
      @current_encode = movie
      encode(movie)
      @current_encode = nil
    end
  end

  def encode(movie)
    if !File.exist?(movie.rip_fn)
      notify( %(Hmmm, #{File.basename(movie.rip_fn)} doesn't seem to exist anymore; skipping.), poke_channel: true )
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

    notify("Starting the encode of \"#{movie.name}\" [#{movie.track_name}] (#{encodes_left}with #{PLATFORM.free_space}G free space).")
    
    movie.set_encode_fn
    movie.change_state(:encoding)
    
    result, timing = PLATFORM.encode(movie)
    log :debug, result
    
    notify("Finished encoding \"#{movie.name}\" [#{movie.track_name}] (took #{timing}).")
    
    log :info, "deleting #{movie.rip_fn}"
    File.delete(movie.rip_fn)
    Dir.rmdir(movie.rip_dir)
    
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

  # What am I doing? Current movie I'm encoding + number of items in queue.
  def what
    [ @current_encode.clone, @queue.size ]
  end

  # Enqueue ripped movies ready to encode, from a prior run.
  def start_pending_encodes
    Movie.where(state: 'ripped').each { |movie| self.add_movie(movie) }
  end

end
