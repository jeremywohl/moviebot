#
# Encoding automata
#

class Encoder
  
  attr :queue  # for testing
  
  def initialize
    @queue = Queue.new
  end
  
  def go
    loop do
      movie = @queue.pop
      encode(movie)
    end
  end

  def encode(movie)
    if !File.exist?(movie.mkv_path)
      notify( %(Hmmm, #{movie.mkv_path} doesn't seem to exist anymore; skipping.), poke_channel: true )
      return
    end

    encodes_left =
      case @queue.size
      when 0
        'no others queued, '
      else
        sprintf("%s left, ", pluralize(@queue.size, 'other', 'others'))
      end

    notify("Starting the encode of \"#{movie.base}.m4v\" (#{encodes_left}with #{PLATFORM.free_space}G free space).")
    
    encode_fn = "#{ENCODING_ROOT}/#{SecureRandom.hex[0...5]}-#{movie.base}.m4v"
    
    result, timing = PLATFORM.encode(movie.mkv_path, encode_fn)
    log :debug, result
    
    notify("Finished encoding of \"#{movie.base}.m4v\" (took #{timing}).")
    
    log :info, "deleting #{movie.mkv_path}"
    File.delete(movie.mkv_path)
    Dir.rmdir(File.dirname(movie.mkv_path))
    
    final_path = "#{DONE_ROOT}/#{movie.base}.m4v"
    if File.exist?(final_path)
      final_path = "#{DONE_ROOT}/#{movie.base}-#{SecureRandom.hex[0...5]}.m4v"
    end

    File.rename(encode_fn, final_path)
  end
  
  def add_movie(m)
    @queue << m
  end
  
end

ENCODER = Encoder.new
Thread.new do
  begin
    ENCODER.go
  rescue => e
    log :error, 'encoder died', exception: e
    notify("I (encoder) die!", poke_channel: true)
  end
end
