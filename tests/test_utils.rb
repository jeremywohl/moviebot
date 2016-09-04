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
      [ 'Wreck-It_Ralph_t00',     'Wreck It Ralph'         ], # hyphens are hard to distinguish
      [ 'ALL_CAPS_AND_PER_THING', 'All Caps and per Thing' ],
      [ "The_King's_Speech",      "The King's Speech"      ], # but we handle apostrophes
      [ 'abcde-Some_Movie_Name',  'Some Movie Name'        ],
    ].each do |test|
      assert_equal(test[1], title_case_fn(clean_fn(test[0])))
    end
  end

end
