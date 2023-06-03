#
# CloudAws mock
#

class CloudAwsMock

  def upload_file(local, remote)
    return true
  end

  def download_file(remote, local)
    FileUtils.touch(local)
    return true
  end

  def delete_files(list)
    return true
  end

  def encode(movie)
    return true
  end

end
