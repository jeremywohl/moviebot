#
# Encoding automata
#

ENCODE = %(#{HANDBRAKE_BIN} --input "%{input}" --output "%{output}" --preset '#{HANDBRAKE_PROFILE}')

class Mp4Spinner
  
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
    encode_fn  = "#{ENCODING_ROOT}/#{SecureRandom.hex[0...5]}-#{movie.base}.m4v"
    encode_cmd = ENCODE % { input: movie.mkv_path, output: encode_fn }
    
    if !File.exists?(movie.mkv_path)
      notify( %(Hmmm, #{movie.mkv_path} doesn't seem to exist anymore; skipping.), poke_channel: true )
      return
    end

    encodes_expl = sprintf("%s %s left, ", @queue.size, pluralize(@queue.size, 'other', 'others'))
    encodes_left = @queue.size > 0 ? encodes_expl : ''

    notify("Starting the encode of \"#{movie.base}.m4v\" (#{encodes_left}with #{free_space}G free space).")
    
    result, timing = external_with_timing encode_cmd
    log :debug, result
    
    notify("Finished encoding of \"#{movie.base}.m4v\" (took #{timing}).")
    
    log :info, "deleting #{movie.mkv_path}"
    File.delete(movie.mkv_path)
    Dir.rmdir(File.dirname(movie.mkv_path))
    
    File.rename(encode_fn, "#{DONE_ROOT}/#{movie.base}.m4v")
  end
  
  def add_movie(m)
    @queue << m
  end
  
end

MP4_SPINNER = Mp4Spinner.new
Thread.new do
  begin
    MP4_SPINNER.go
  rescue => e
    log :error, 'mp4spinner died', exception: e
    notify("I (mp4spinner) die!", poke_channel: true)
  end
end
