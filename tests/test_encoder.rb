#
# Test encoder
#

require_relative 'common'

class TestEncoder < MiniTest::Test

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
