#
# Set -- A concurrent set, specific to movies
#

class MovieSet

  def initialize
    @mutex = Mutex.new
    @hash  = {}
  end

  def add(movie)
    @mutex.synchronize do
      @hash[movie.id] = movie
    end
  end

  def <<(movie)
    self.add(movie)
  end

  def remove(movie)
    @mutex.synchronize do
      @hash.delete(movie.id)
    end
  end

  def size
    size = 0
    @mutex.synchronize do
      size = @hash.size
    end
    return size
  end

  # Iterator filtered for state, ordered by id. Point-in-time when called. Set changes afterwards are unnoticed.
  def each_in_state(state, &block)
    movies = nil

    @mutex.synchronize do
      movies = @hash.values.select { |m| m.encode_state == state.to_s }.sort_by(&:id)
    end

    movies.each(&block)
  end

  # Return the first movie in this state, ordered by id.
  def first_in_state(state)
    movie = nil

    @mutex.synchronize do
      movie = @hash.values.select { |m| m.encode_state == state.to_s }.sort_by(&:id).first
    end

    return movie
  end

  # Is set empty for movies in this state?
  def empty_for_state?(state)
    length = 0

    @mutex.synchronize do
      length = @hash.select { |k,v| v.encode_state == state.to_s }.length
    end

    return length == 0
  end

end
