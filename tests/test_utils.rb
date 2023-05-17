#
# Test utils
#

require_relative 'common'

class TestUtils < MiniTest::Test

  def test_title_casing
    # clean
    [
      [ 'abcde-etc', 'etc'     ],
      [ 'abc_t00',   'abc'     ],
      [ 'a_b_c_d',   'a b c d' ],
      [ 'a  a   a',  'a a a'   ],
    ].each do |test|
      assert_equal(test[1], clean_fn(test[0]))
    end

    # title case
    [
      [ 'Wreck-It_Ralph_t00',                    'Wreck It Ralph'         ], # hyphens are hard to distinguish
      [ 'Wreck-It_Ralph_-FPL_MainFeature_t00',   'Wreck It Ralph'         ],
      [ 'ALL_CAPS_AND_PER_THING',                'All Caps and per Thing' ],
      [ "The_King's_Speech",                     "The King's Speech"      ], # but we handle apostrophes
      [ 'abcde-Some_Movie_Name',                 'Some Movie Name'        ],
    ].each do |test|
      assert_equal(test[1], title_case_fn(clean_fn(test[0])))
    end
  end

  def test_format_time_diff
    [
      [ Time.now,                 "0s" ],
      [ Time.now - 59,           "59s" ],
      [ Time.now - 3599,     "59m:59s" ],
      [ Time.now - 85_000,   "23h:36m" ],
    ].each do |test|
      assert_equal(test[1], format_time_diff(test[0]))
    end
  end

  def test_format_size
    assert_equal( "0.6G", format_size(   600_000_000))
    assert_equal("27.1G", format_size(27_100_000_000))
  end

end
