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
      [ Time.now -     59,       "59s" ],
      [ Time.now -  3_485,   "58m:05s" ],
      [ Time.now -  3_599,   "59m:59s" ],
      [ Time.now - 83_140,   "23h:05m" ],
      [ Time.now - 85_000,   "23h:36m" ],
    ].each do |test|
      assert_equal(test[1], format_time_diff(test[0]))
    end
  end

  def test_format_size
    assert_equal( "0.6G", format_size(   600_000_000))
    assert_equal("27.1G", format_size(27_100_000_000))
  end

  def test_hash_encryption
    [
      { foo: 'bar', jim: 'bean' },
      { one_track: 1            },
    ].each do |test|
      # normalize keys with a pass thru JSON, but test with the convential literal we'll use
      hash    = JSON.parse(test.to_json)
      crypted = encrypt_hash(test)

      refute_equal hash, crypted
      assert_equal(hash, decrypt_hash(crypted))
    end
  end

  def test_human_list
    [
      [ [               ],  "",           ],
      [ [ 'a'           ],  "a"           ],
      [ [ 'a', 'b'      ],  "a and b"     ],
      [ [ 'a', 'b', 'c' ],  "a, b, and c" ],
    ].each do |test|
      assert_equal(test[1], human_list(test[0]))
    end
  end

  def test_interpolate_cmd
    [
      {
        input:  [ "a %{broken} string --option %{folder}", { broken: 'fixed', folder: 'yahoo beans' }, ],
        output: [ 'a', 'fixed', 'string', '--option', 'yahoo beans' ]
      },
    ].each do |test|
      assert_equal(test[:output], interpolate_cmd(test[:input][0], test[:input][1]))
    end
  end

  def test_debug_logfile
    old_value = change_constant(:LOG_DEBUG, true)

    f = debug_logfile(label: 'foo')
    assert_equal File, f.class
    assert_match(/^\d+-foo-\w+$/, File.basename(f.path))

    f = debug_logfile(label: 'foo', movie_id: 1)
    assert_equal File, f.class
    assert_match(/^\d+-1-foo-\w+$/, File.basename(f.path)) 

    change_constant(:LOG_DEBUG, false)

    f = debug_logfile(label: 'foo')
    assert_equal StringIO, f.class

    change_constant(:LOG_DEBUG, old_value)
  end

  def test_articleize_number
    # a
    [ 0, 1, 7, 70 ].each do |test|
      assert_equal("a #{test}", articleize_number(test))
    end

    # an
    [ 8, 11, 80, 81 ].each do |test|
      assert_equal("an #{test}", articleize_number(test))
    end
  end

end
