#
# Moving automata
#

TARGETS = { 'movies' => 'Movies', 'kid' => 'Movies/kid', 'tv' => 'Television', 'anim' => 'Movies/animation'}

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
    cmd   = "mv '#{move.source}' '/Volumes/Media Black/#{TARGETS[move.target]}'"
    start = Time.now
    
    puts cmd
    puts `#{cmd}`
    
    notify("Archived \"#{File.basename(move.source, '.*')}\" to #{move.target} (took #{format_time_diff(start)}).")
  end
  
  def add_move(m)
    @queue << m
  end
  
end

MOVER = Mover.new
Thread.new do
  begin
    MOVER.go
  rescue
    notify("I (mover) die!", poke_channel: true)
    puts $!, $@
  end
end
