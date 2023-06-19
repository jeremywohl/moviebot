#
# Encoding automata
#

class Encoder
  
  def self.start_async(impl_class)
    Encoder.new(impl_class)
  end

  def initialize(impl_class)
    @impl = impl_class.send(:start_async, self)
    start_pending_encodes
  end

  # Enqueue ripped movies ready to encode, from a prior run.
  def start_pending_encodes
    Movie.where(state: 'ripped').each { |movie| self.add_movie(movie) }
  end

  def add_movie(movie)
    if !File.exist?(movie.rip_fn)
      SLACK.send_text_message( %(Hmmm, #{File.basename(movie.rip_fn)} doesn't seem to exist anymore; skipping.), poke_channel: true )
      movie.change_state(:failed)
      return
    end

    queue_size = @impl.queue_size
    encodes_left =
      case queue_size
      when 0
        'no others queued, '
      else
        sprintf("%s left, ", pluralize(queue_size, 'other', 'others'))
      end

    log :info, "(movie id #{movie.id}) encoding [#{movie.name}]"
    SLACK.send_text_message("Starting to encode \"#{movie.name}\" (#{encodes_left}with #{PLATFORM.free_space}G free space).")
    
    movie.encode_start_time = Time.now.to_i
    movie.save
    movie.change_state(:encoding)
    
    @impl.add_movie(movie)
  end

  def complete_movie(movie, status)
    case status
    when :fail
      movie.change_state(:failed)
      log :info, "(movie id #{movie.id}) failed to encode [#{movie.name}]"
      SLACK.send_text_message("There was an error while encoding \"#{movie.name}\"; please see the log.")
    when :shutdown
      log :info, "Encoder shutdown and cleanup..."
      File.delete(movie.encode_fn) if File.exist?(movie.encode_fn)
      movie.change_state(:ripped)  # return to ripped state for later encoding
    when :success
      log :info, "deleting #{movie.rip_fn}"
      FileUtils.remove_dir(movie.rip_dir)

      movie.encode_time = Time.now - movie.encode_start_time
      movie.encode_size = File.size(movie.encode_fn)
      movie.save

      movie.set_done_fn
      File.rename(movie.encode_fn, movie.done_fn)

      movie.change_state(:done)

      size_msg  = "#{format_size(movie.size)} -> #{format_size(movie.encode_size)}"
      log :info, "(movie id #{movie.id}) finished encoding [#{movie.name}] in #{format_time(movie.encode_time)}, #{size_msg}"
      SLACK.send_text_message("Finished encoding \"#{movie.name}\" (took #{format_time(movie.encode_time)}, #{size_msg}).")
    end
  end

end
