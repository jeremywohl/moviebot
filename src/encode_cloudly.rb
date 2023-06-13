#
# Encode in the cloud
#
# Encodes are split into three operations: upload, encode, and download. We operate on the
# whole queue at once, prioritizing operations as follows: 1) start any encode with a ready
# file in cloud, 2) upload files to cloud, 3) download files. We only run one upload/download
# at a time, to preserve bandwidth. Any number of encodes can run in parallel. Since cloud compute
# pricing is by the second, and creation and package setup is fast, we don't need to batch
# multiple encodes on a single instance. So each instance runs a linear script and terminates,
# and its lifetime is scoped only to encode time. This may change with other cloud implementations.
#
# Provider-specific calls are delegated. We depend on those methods to retry APIs until
# sufficiently convinced there is a permanent error. We hard fail at this level.
#
class EncodeCloudly

  def initialize(parent)
    @parent = parent

    @movies       = MovieSet.new  # all the movies we're currently working on
    @state_change = Queue.new     # signal some movie (unspecified) is ready for next step
  end

  def self.start_async(parent)
    encoder = EncodeCloudly.new(parent)

    wrapped_thread("cloud encoder") do
      encoder.go
    end

    return encoder
  end

  def go
    #continue_ongoing_encodes

    loop do
      @state_change.pop
      perform_work
    end
  end

  def add_movie(movie)
    movie.set_encode_cloud_name
    movie.change_encode_state(:ready_for_upload)
    @movies << movie
    flag_state_change
  end

  def queue_size
    @movies.size
  end

  private

  def flag_state_change
    @state_change << 1
  end

  # Different than the one-shot local encoder, we can pick up intermediate states of completion,
  # as long as we've done a good job returning erroring segments to ready_for_* states.
  # TODO: this needs work, develop a clearer idea of controlling this distributed work
  def continue_ongoing_encodes
    Movie.where(state: 'encoding').each { |movie| @movies << movie }
    flag_state_change
  end

  # current state, new state, how many should be processed?
  Priorities = [
    [ :ready_for_encode,   :encoding,    :many ],
    [ :ready_for_upload,   :uploading,   :one  ],
    [ :ready_for_download, :downloading, :one  ],
    [ :ready_for_cleanup,  :cleaning,    :many ],
  ]

  # Perform work in priority order.
  def perform_work
    Priorities.each do |state, new_state, how_many|
      count = 0

      case how_many
      when :many
        @movies.each_in_state(state) do |movie|
          count += 1
          movie.change_encode_state(new_state)
          Thread.new { dowork(movie) }
        end
      when :one
        if ( movie = @movies.first_in_state(state) )
          count += 1
          movie.change_encode_state(new_state)
          dowork(movie)
        end
      end

      break unless count == 0  # do not advance unless there is no higher-priority work
    end
  end

  # Perform action and hard fail if error. We depend on provider-specific class to retry transient API issues.
  def dowork(movie)
    log :debug, "(movie id #{movie.id}) do -> #{movie.encode_state}"
    success = self.send("do_#{movie.encode_state}".to_sym, movie)

    if !success
      movie.change_encode_state(:done)
      @parent.complete_movie(movie, :fail)
    end
  end

  def do_uploading(movie)
    log :debug, "(movie id #{movie.id}) uploading #{movie.rip_fn} to #{movie.encode_cloud_name}.mkv"
    success = CLOUD.upload_file(movie.rip_fn, movie.encode_cloud_name + '.mkv')
    log :debug, "(movie id #{movie.id}) completed uploading #{movie.encode_cloud_name}.mkv" if success
    
    movie.change_encode_state(:ready_for_encode) if success
    flag_state_change

    return success
  end

  def do_encoding(movie)
    log :debug, "(movie id #{movie.id}) encoding step"
    success = CLOUD.encode(movie)
    log :debug, "(movie id #{movie.id}) completed encoding step" if success

    movie.change_encode_state(:ready_for_download) if success
    flag_state_change

    return success
  end

  def do_downloading(movie)
    movie.set_encode_fn
    log :debug, "(movie id #{movie.id}) downloading #{movie.encode_cloud_name}.m4v to [#{movie.encode_fn}]"
    success = CLOUD.download_file(movie.encode_cloud_name + '.m4v', movie.encode_fn)
    log :debug, "(movie id #{movie.id}) completed downloading #{movie.encode_cloud_name}.m4v" if success

    if success
      movie.change_encode_state(:ready_for_cleanup)
    end

    flag_state_change
    return success
  end

  def do_cleaning(movie)
    CLOUD.delete_files([ movie.encode_cloud_name + '.mkv', movie.encode_cloud_name + '.m4v' ])  # ignore fail
    @movies.remove(movie)
    movie.change_encode_state(:done)
    @parent.complete_movie(movie, :success)
    true
  end

end
