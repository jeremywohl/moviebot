#
# Cloud AWS implementation
#

class CloudAws

  def initialize
    @creds     = Aws::Credentials.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    @bucket    = Aws::S3::Resource.new(region: AWS_REGION, credentials: @creds).bucket(AWS_S3_BUCKET)
    @ec2       = Aws::EC2::Resource.new(region: AWS_REGION, credentials: @creds)
    @ec2client = Aws::EC2::Client.new(region: AWS_REGION, credentials: @creds)
  end

  def upload_file(local, remote)
    wrapped_retry("upload [#{local}] to #{remote}", returnval: :is_error_free) do
      @bucket.object(remote).upload_file(local)
    end
  end

  def download_file(remote, local)
    wrapped_retry("download #{remote} -> [#{local}]", returnval: :is_error_free) do
      @bucket.object(remote).download_file(local)
    end
  end

  def delete_files(list)
    list.each do |key|
      success = wrapped_retry("delete cloud file #{key}", returnval: :is_error_free) do
        @bucket.object(key).delete
      end
      return false if !success
    end

    true
  end

  def encode(movie)
    success = false

    wrapped_retry("encode movie id #{movie.id} name [#{movie.name}]", returnval: :call_result) do
      instance = create_instance(movie)

      begin
        success = run_script(movie, instance, render_script(movie))
      ensure
        terminate_instance(movie, instance)
      end
    end

    success
  end

  def create_instance(movie)
    log :debug, "(movie id #{movie.id}) aws: creating instance"

    instances = @ec2.create_instances({
      image_id: AWS_IMAGE_ID,
      min_count: 1,
      max_count: 1,
      key_name: AWS_SSH_KEY_NAME,
      instance_type: AWS_INSTANCE_TYPE,
      security_group_ids: [ AWS_SG_GROUP_ID ],
      block_device_mappings: [
        {
          device_name: '/dev/sda1', # this might change depending on the AMI
          ebs: {
            # (AWS uses GiB disk units!)
            # volume is twice raw size, assume 2GiB lost to OS, at least 8GiB minimum disk
            volume_size: [ ( movie.size.to_f / 2**30 * 2 + 2 ).ceil, 8 + 2 ].max,
            delete_on_termination: true,
            volume_type: 'gp2',
          },
        },
      ],
      instance_market_options: {
        market_type: 'spot',
        # other options default to our desired one-time, and terminate on interruption
      },
    })

    instance = instances.first

    instance.wait_until_running
    instance.reload

    log :debug, "(movie id #{movie.id}) aws: created spot instance #{instance.id}"

    return instance
  end

  def render_script(movie)
    template_fn = File.join(File.expand_path(File.dirname(__FILE__)), 'templates', 'cloud-aws-encode.sh.erb')
    rendered = ERB.new(File.read(template_fn)).result_with_hash({
      aws_key:    AWS_ACCESS_KEY_ID,
      aws_secret: AWS_SECRET_ACCESS_KEY,
      bucket:     AWS_S3_BUCKET,
      name:       movie.encode_cloud_name,
    })
  end

  def run_script(movie, instance, script)
    log :debug, "(movie id #{movie.id}) aws: running script"

    io = StringIO.new(script)

    script_log = debug_logfile(movie_id: movie.id, label: 'encode', description: "cloud script output")
    ensure_callback = proc { script_log.close }

    Retryable.retryable(tries: RETRY_RETRIES, sleep: RETRY_BACKOFF, ensure: ensure_callback) do
      script_log.puts "Started at #{Time.now.to_s}. (This may restart on temporary API errors.)"
      script_log.puts '-' * 60

      begin
        exit_code = nil
        Net::SSH.start(instance.public_ip_address, "ubuntu", keys: [ SSH_PRIVKEY_PATH ]) do |ssh|
          ssh.scp.upload!(io, "encode.sh")
          ssh.exec! 'chmod +x ./encode.sh'

          ssh.open_channel do |ch|
            ch.exec './encode.sh 2>&1' do |ch, success|
              abort 'failed to run script' unless success

              ch.on_data do |ch, data|
                script_log.write(data)
              end

              ch.on_request("exit-status") do |ch, data|
                exit_code = data.read_long
              end
            end
          end

          ssh.loop
        end

        script_log.puts '-' * 60
        script_log.puts "Completed at #{Time.now.to_s} with exit_code: #{exit_code}."

        log :debug, "(movie id #{movie.id}) aws: finished running script with exit_code #{exit_code}"
        return exit_code == 0
      rescue IOError
        log :debug, "(movie id #{movie.id}) aws: ioerror, instance closed on us; will retry"
        raise
      end
    end
  end

  def terminate_instance(movie, instance)
    log :debug, "(movie id #{movie.id}) aws: terminating instance #{instance.id}"
    @ec2.client.terminate_instances({ instance_ids: [ instance.id ] })
  end
  
end
