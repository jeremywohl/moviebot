#
# Moving automata
#

class Mover
  
  def initialize
    @queue = Queue.new
  end
  
  def go
    loop do
      movie = @queue.pop
      move(movie)
    end
  end

  def move(move)
    # TODO: refactor to platform
    cmd = %(mv "#{move.source}" "#{ARCHIVE_ROOT}/#{ARCHIVE_TARGETS[move.target]}")
    # TODO: handle failures
    _, _, timing = external_with_timing cmd

    SLACK.send_text_message("Archived \"#{File.basename(move.source, '.*')}\" to #{move.target} (took #{timing}).")
  end
  
  def add_move(m)
    @queue << m
  end
  
end

MOVER = Mover.new
Thread.new do
  begin
    MOVER.go
  rescue => e
    log :error, "mover died", exception: e
    SLACK.send_text_message("I (mover) die!", bang: true, poke_channel: true)
  end
end
