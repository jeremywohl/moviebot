#
# Encode on this here machine
#

class EncodeLocally
  
  attr :queue  # for testing
  
  def initialize(parent)
    @parent = parent
    @queue  = Queue.new
  end

  def self.start_async(parent)
    encoder = EncodeLocally.new(parent)

    wrapped_thread "encoder (local)" do
      encoder.go
    end

    return encoder
  end

  def go
    loop do
      encode(@queue.pop)
      break if $shutdown
    end
  end

  def add_movie(m)
    @queue << m
  end

  def queue_size
    @queue.size
  end

  private

  def encode(movie)
    movie.set_encode_fn

    exit_code, result, _ = PLATFORM.encode(movie)

    script_log = debug_logfile(movie_id: movie.id, label: 'encode', description: "local script output")
    script_log.write result
    script_log.close

    if $shutdown
      @parent.complete_movie(movie, status: :shutdown)
      return
    end

    if exit_code > 0
      @parent.complete_movie(movie, status: :fail)
      return
    end
    
    @parent.complete_movie(movie, :success)
  end

end
