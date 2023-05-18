##
## Personal settings -- you must change these
##

# Where should we do our work?
# (see common.rb for MOVIES_ROOT assignment)

# Where do you archive your movies? (optional)
ARCHIVE_ROOT    = '/archive/path/to/movies'
ARCHIVE_TARGETS = { 'movies' => 'movies', 'kid' => 'kid', 'tv' => 'television', 'anim' => 'animation'}

# Slack settings
SLACK_API_TOKEN = 'abcdefghijklmnopqrstuvwxyz'
SLACK_CHAT_NAME = 'movie'   # how you get moviebot's attention
SLACK_CHANNEL   = 'general' # moviebot will always respond here

##
## Additional settings -- the defaults are usually OK
##

# Where should we do our work?
ENCODING_ROOT = "#{MOVIES_ROOT}/_encoding"
RIPPING_ROOT  = "#{MOVIES_ROOT}/_ripping"
DONE_ROOT     = "#{MOVIES_ROOT}/_done"

# Where is Handbrake command-line binary?
HANDBRAKE_BIN = '/Applications/Utilities/HandBrakeCLI'
HANDBRAKE_PROFILE = 'High Profile'

# MakeMKV command-line binary?
MAKEMKV_BIN = '/Applications/MakeMKV.app/Contents/MacOS/makemkvcon'
MKV_SCAN_MINLENGTH = 20     # minutes
MKV_RIP_MINLENGTH  = 50     # minutes

# Gory details?
LOG_DEBUG = false
