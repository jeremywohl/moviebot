#
# Test MovieSet
#

require_relative 'common'

class TestMovieSet < MiniTest::Test

  def test_stuff
    m1 = Movie.new
    m1.id = 1
    m1.encode_state = 'ready_for_upload'

    m2 = Movie.new
    m2.id = 2
    m2.encode_state = 'ready_for_download'
    
    ms = MovieSet.new
    ms.add(m1)
    ms.add(m2)

    assert_equal 2,     ms.size
    assert_equal false, ms.empty_for_state?(:ready_for_upload)
    assert_equal true,  ms.empty_for_state?(:uploaded)
    assert_equal false, ms.empty_for_state?(:ready_for_download)

    m3 = Movie.new
    m3.id = 3
    m3.encode_state = 'ready_for_upload'
    ms << m3

    assert_equal 3, ms.size
    assert_equal 1, ms.first_in_state(:ready_for_upload).id

    count = 0
    ms.each_in_state(:ready_for_upload) do |m|
      assert_includes [ 1, 3 ], m.id
      count += 1
    end

    assert_equal 2, count

    ms.remove(m1)

    assert_equal 2, ms.size

    count = 0
    ms.each_in_state(:ready_for_upload) do |m|
      assert_includes [ 3 ], m.id
      count += 1
    end

    assert_equal 1, count

    assert_equal false, ms.empty_for_state?(:ready_for_download)
    assert_equal 2,     ms.size
    ms.remove(m2)
    assert_equal 1,     ms.size
    assert_equal true,  ms.empty_for_state?(:ready_for_download)
  end
  
end
