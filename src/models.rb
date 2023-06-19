#
# database models
#

# Encode fields: encode_start_time, encode_state, encode_cloud_name
# Other fields:  rip_time, encode_time, encode_size

class Movie < Sequel::Model

  def validate
    super
    validates_includes %w( pending ripping ripped encoding done archived failed abandoned ), :state
    validates_includes %w(
      pending
      ready_for_upload uploading
      ready_for_encode encoding
      ready_for_download downloading
      ready_for_cleanup cleaning
      done
    ), :encode_state
  end

  def set_from_track(track)
    self.disc_name  = track.disc_name
    self.track_id   = track.id
    self.track_name = track.name
    self.time       = track.time
    self.size       = track.size

    # Name: remove extension, clean and title case, prepend disc name if ambiguous, and add track number;
    #   unknown tracks may be labeled with 2 characters (e.g. "D1") or as 'title'
    base      = File.basename(self.track_name, '.*')
    clean     = title_case_fn(clean_fn(base))
    prefix    = ( clean == 'Title' || clean.size == 2 ) ? "#{self.disc_name}-" : ''
    track_tag = "-#{self.track_id+1}"
    self.name = prefix + clean + track_tag

    return self
  end

  def set_rip_paths
    self.refresh
    self.rip_dir = "#{RIPPING_ROOT}/#{SecureRandom.alphanumeric(5)}-#{self.name}"
    self.rip_fn  = "#{self.rip_dir}/#{self.track_name}"
    self.save
  end

  def set_encode_cloud_name
    self.encode_cloud_name = SecureRandom.alphanumeric(30)
    self.save
  end

  def set_encode_fn
    self.refresh
    self.encode_fn = "#{ENCODING_ROOT}/#{SecureRandom.alphanumeric(5)}-#{self.name}.m4v"
    self.save
  end

  def set_done_fn
    self.refresh
    self.done_fn = "#{DONE_ROOT}/#{self.name}.m4v"
    if File.exist?(self.done_fn)
      self.done_fn = "#{DONE_ROOT}/#{self.name}-#{SecureRandom.hex[0...5]}.m4v"
    end
    self.save
  end

  def change_state(new_state)
    self.state = new_state.to_s  # accept both strings and symbols
    self.save
  end

  def change_encode_state(new_state)
    self.encode_state = new_state.to_s
    self.save
  end

end
