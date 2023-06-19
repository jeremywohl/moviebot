#
# Test database
#

require_relative 'common'

class TestDatabase < MiniTest::Test

  def test_simple_create
    movie = Movie.new
    movie.name = 'asdf'
    movie.save
  end

  def test_from_track
    track = OpenStruct.new(disc_name: 'disc', id: 1, name: 'Wreck-It_Ralph_t00.mkv', time: 24, size: 32)
    movie = Movie.new.set_from_track(track)
    assert_equal 'disc',                   movie.disc_name
    assert_equal 1,                        movie.track_id
    assert_equal 'Wreck-It_Ralph_t00.mkv', movie.track_name
    assert_equal 24,                       movie.time
    assert_equal 32,                       movie.size

    assert_equal 'Wreck It Ralph-2', movie.name

    # more names

    track = OpenStruct.new(disc_name: 'disc', id: 1, name: 'B1_t01.mkv', time: 24, size: 32)
    movie = Movie.new.set_from_track(track)
    assert_equal 'disc-B1-2', movie.name

    track = OpenStruct.new(disc_name: 'disc', id: 1, name: 'title_t01.mkv', time: 24, size: 32)
    movie = Movie.new.set_from_track(track)
    assert_equal 'disc-Title-2', movie.name
  end

  def test_set_rip_paths
    track = OpenStruct.new(disc: 'disc', id: 1, name: 'Wreck-It_Ralph_t00.mkv', time: 24, size: 32)
    movie = Movie.new.set_from_track(track)
    movie.save
    movie.set_rip_paths

    # We don't have control over MakeMKV's output filename, it will use its discovered track name.
    assert_equal movie.rip_fn, "#{movie.rip_dir}/Wreck-It_Ralph_t00.mkv"
  end

end
