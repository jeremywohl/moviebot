#
# database models
#

class Movie < Sequel::Model
  def validate
    super
    validates_includes %w( pending ripping ripped encoding done failed abandoned ), :state
  end

  def set_from_track(track)
    self.disc       = track.disc
    self.track_id   = track.id
    self.track_name = track.name
    self.time       = track.time
    self.size       = track.size

    name = File.basename(self.track_name, '.*')
    self.name = title_case_fn(clean_fn(name))

    return self
  end

  def set_rip_paths
    self.rip_dir = "#{RIPPING_ROOT}/#{SecureRandom.alphanumeric(5)}-#{self.name}"
    self.rip_fn  = "#{self.rip_dir}/#{self.track_name}"
    self.save
  end

  def set_encode_fn
    self.encode_fn = "#{ENCODING_ROOT}/#{SecureRandom.alphanumeric(5)}-#{self.name}.m4v"
    self.save
  end

  def change_state(new_state)
    self.state = new_state.to_s  # accept both strings and symbols
    self.save
  end
end
