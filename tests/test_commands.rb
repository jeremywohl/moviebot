#
# Test commands
#

require_relative 'common'

class TestCommands < MiniTest::Test

  def setup
    # reset db
    DB[:movies].delete
  end

  def test_what_command
    # time ordered
    Movie.new(name: 'vwx', track_name: 'vwx_t00.mkv', state: 'failed').save
    Movie.new(name: 'stu', track_name: 'stu_t00.mkv', state: 'done').save
    Movie.new(name: 'pqr', track_name: 'pqr_t00.mkv', state: 'encoding').save
    Movie.new(name: 'mno', track_name: 'mno_t00.mkv', state: 'ripped').save
    Movie.new(name: 'jkl', track_name: 'jkl_t00.mkv', state: 'ripped').save
    Movie.new(name: 'ghi', track_name: 'ghi_t00.mkv', state: 'ripping').save
    Movie.new(name: 'def', track_name: 'def_t00.mkv').save
    Movie.new(name: 'abc', track_name: 'abc_t00.mkv').save

    output = <<~END
    Here is what's in progress:
    >abc [abc_t00.mkv] (waiting to be ripped)
    >def [def_t00.mkv] (waiting to be ripped)
    >ghi [ghi_t00.mkv] (now ripping)
    >jkl [jkl_t00.mkv] (waiting to be encoded)
    >mno [mno_t00.mkv] (waiting to be encoded)
    >pqr [pqr_t00.mkv] (now encoding)
    END

    COMMANDS.what_command(nil)
    assert_equal output, SLACK.history[-1]
  end

end
