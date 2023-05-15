#
# Test encoder
#

require_relative 'common'

class TestEncoder < MiniTest::Test

  def setup
    FileUtils.rm Dir["#{DONE_ROOT}/*.m4v"]
    FileUtils.rm_r Dir["#{RIPPING_ROOT}/*"]
  end

  def test_encode
    movie = Movie.new(name: "title00", track_name: "title00.mkv").save
    movie.set_rip_paths
    Dir.mkdir(movie.rip_dir)
    FileUtils.touch(movie.rip_fn)

    ENCODER.add_movie(movie)
    sleep 0.1
    
    assert_equal(false, File.exist?(movie.rip_fn))
    assert_equal(true,  File.exist?(movie.done_fn))

    assert_equal( %|Starting the encode of "title00.m4v" (no others queued, with 22G free space).|, SLACK.history[-2] )
    assert_equal( %|Finished encoding of "title00.m4v" (took 0).|, SLACK.history[-1] )
  end
  
  def test_absent_rip
    movie = Movie.new(name: "abc", track_name: "abc.mkv").save
    movie.set_rip_paths
    ENCODER.add_movie(movie)
    sleep 0.1
    
    assert_match(/^Hmmm, abc.mkv doesn't seem to exist/, SLACK.pop)
  end
  
  def test_duplicate_names
    # create one file
    movie = Movie.new(name: "title00", track_name: "title00.mkv").save
    movie.set_rip_paths
    Dir.mkdir(movie.rip_dir)
    FileUtils.touch(movie.rip_fn)
    ENCODER.add_movie(movie)
    sleep 0.1
    
    assert_equal(true, File.exist?("#{DONE_ROOT}/title00.m4v"))
    
    # and then another with the same name (but a different mkv path)
    movie = Movie.new(name: "title00", track_name: "title00.mkv").save
    movie.set_rip_paths
    Dir.mkdir(movie.rip_dir)
    FileUtils.touch(movie.rip_fn)
    ENCODER.add_movie(movie)
    sleep 0.1

    files = Dir["#{DONE_ROOT}/*.m4v"]
    assert_equal(2, files.size)
    assert_equal(true, files.select { |x| x =~ /\/title00-\w{5}\.m4v$/ }.size == 1)
  end

end
