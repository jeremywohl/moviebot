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

    notify("Starting the encode of \"#{movie.base}.m4v\" (with #{free_space}G free space).")
    
    start = Time.now
    puts encode_cmd
    puts `#{encode_cmd}`
    
    notify("Finished encoding of \"#{movie.base}.m4v\" (took #{format_time_diff(start)}).")
    
    puts "deleting #{movie.mkv_path}"
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
  rescue
    notify("I (mp4spinner) die!", poke_channel: true)
    puts $!, $@
  end
end
