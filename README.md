Moviebot
========

Moviebot is a Slack robot that automates the rip and encode of movie DVDs and Blu-rays.  Moviebot watches your disc drive and, behind the scenes, uses MakeMKV and Handbrake to stir up beautiful m4v's.  Meanwhile you sit on your couch and chat up moviebot.  (Let the kids swap discs.)

_Warning: Please observe your country's laws regarding commercial entertainment.  You may or may not be able to make backup copies of movies you own._

  * [What it looks like](#what-it-looks-like)
  * [Setting up Moviebot](#setting-up-moviebot)
  * [Commands](#commands)

# What it looks like

TODO: amazing screenshot!

# Setting up Moviebot

## Clone this repository

   # git clone git@github.com:jeremywohl/moviebot.git

or

   # git clone https://github.com/jeremywohl/moviebot.git

## Prep a config

Copy the sample config.

    # cp config.rb.samp config.rb

Open up `config.rb` and edit MOVIES_ROOT.  Files are in one of three stages: ripping, encoding, and done, and you can watch them move from one to the next.  Here's a sample tree.

![](docs/folders.png)

You'll need plenty of space -- high bit-rate Blu-rays will need 50GB to rip and compress.

## Setup a Slack team

You'll probably want to [setup a new Slack team](https://slack.com/create) for you or your family/cohorts.  Go do that.

## Create a Bot integration

[Create a Slack bot user](https://my.slack.com/services/new/bot) and copy the API token into `config.rb`.

![](docs/newbot.png)

## Downloads

1. [Download](https://handbrake.fr/downloads2.php) and install Handbrake CLI.
2. [Download](http://www.makemkv.com/download/) and install MakeMKV.

## Final config

Look over the rest of `config.rb`, though the defaults are probably suitable.

## Running

Start 'er up.

    # ./start

At this point, you should see action in your Slack client / web page.  If not, something is terribly, terribly wrong.  Cheers!

![](docs/wakingup.png)

(Equally exciting is stopping!)

    # ./stop

Now throw a disc into your optical drive.  After some churning you should see some results.

![](docs/newdisc.png)

# Commands

TODO.  For now, type `movie help` in Slack (or using whatever prefix you chose).
