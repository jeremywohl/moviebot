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
    Dir.mkdir("#{RIPPING_ROOT}/xyz")
    FileUtils.touch("#{RIPPING_ROOT}/xyz/title00.mkv")

    movie = OpenStruct.new(mkv_path: "#{RIPPING_ROOT}/xyz/title00.mkv", base: "title00")
    MP4_SPINNER.add_movie(movie)
    sleep 0.1
    
    assert_equal(false, File.exist?("#{RIPPING_ROOT}/xyz/title00.mkv"))
    assert_equal(true,  File.exist?("#{DONE_ROOT}/title00.m4v"))

    assert_equal( %|Starting the encode of "title00.m4v" (with 122G free space).|, SLACK.history[-2] )
    assert_equal( %|Finished encoding of "title00.m4v" (took 0).|, SLACK.history[-1] )
  end
  
  def test_absent_rip
    movie = OpenStruct.new(mkv_path: "abc.mkv", base: "abc")
    MP4_SPINNER.add_movie(movie)
    sleep 0.1
    
    assert_match(/^Hmmm, abc.mkv doesn't seem to exist/, SLACK.pop)
  end
  
  def test_duplicate_names
    FileUtils.rm Dir["#{DONE_ROOT}/*.m4v"]  # clear the decks
    
    # create one file
    Dir.mkdir("#{RIPPING_ROOT}/abc")
    FileUtils.touch("#{RIPPING_ROOT}/abc/title00.mkv")

    movie = OpenStruct.new(mkv_path: "#{RIPPING_ROOT}/abc/title00.mkv", base: "title00")
    MP4_SPINNER.add_movie(movie)
    sleep 0.1
    
    assert_equal(true, File.exist?("#{DONE_ROOT}/title00.m4v"))
    
    # and then another with the same name, but should result in a modified path
    Dir.mkdir("#{RIPPING_ROOT}/def")
    FileUtils.touch("#{RIPPING_ROOT}/def/title00.mkv")

    movie = OpenStruct.new(mkv_path: "#{RIPPING_ROOT}/def/title00.mkv", base: "title00")
    MP4_SPINNER.add_movie(movie)
    sleep 0.1

    files = Dir["#{DONE_ROOT}/*.m4v"]
    assert_equal(2, files.size)
    assert_equal(true, files.select { |x| x =~ /\/title00-\w{5}\.m4v$/ }.size == 1)
  end

end
