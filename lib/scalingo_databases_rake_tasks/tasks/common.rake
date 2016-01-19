require 'uri'
require 'open3'

namespace :scalingo do
  private

  def confirm_remote(database)
    print("You're about to restore your remote database #{database}.\nData will be destroyed. (y/N) ")
    input = STDIN.gets.strip.downcase
    if input != 'y'
      abort
    end
  end

  def archive_name name = "dump"
    "#{Rails.root}/tmp/#{name}.tar.gz"
  end

  def make_tmp_dir
    FileUtils.mkdir_p 'tmp'
  end

  def remote_credentials app, variable
    output = `scalingo -a #{app} env | grep "^#{variable}=" | cut -d '=' -f2 | tr -d '\n'`
    uri = URI(output.strip)
    if uri.to_s.blank?
      raise VariableError
    else
      [uri.path[1..-1], uri.user, uri.password]
    end
  end

  def start_scalingo_tunnel app, variable
    cmd = "scalingo -a #{app} db-tunnel -p 27717 #{variable}"
    puts "*** Executing #{cmd}"
    i, o, thr = Open3::pipeline_rw cmd

    while true
      read_line(o) do |line|
        # puts line # debug
        if line.include?("Encrypted")
          abort "*** Your SSH key is encrypted. This gem is only compatible with SSH agents or unencrypted keys."
        end

        if line.include?("address already in use")
          abort "*** Address 127.0.0.1:27717 is already in use."
        end

        if line.include?("'127.0.0.1:27717'")
          return thr[0].pid
        elsif line.include?("'127.0.0.1:")
          abort "*** Address 127.0.0.1:27717 is already in use."
        end
      end
    end
  end

  def read_line out
    line = ""
    while line == ""
      sleep 0.2
      begin
        line = out.read_nonblock(200)
        yield(line)
      rescue EOFError, IO::EAGAINWaitReadable ; end
    end
  end

  def open_tunnel default_env_name
    app = ENV["APP"]
    variable = ENV["DB_ENV_NAME"] || default_env_name
    unless app
      abort 'ENV["APP"] missing.'
    end
    unless variable
      abort 'ENV["DB_ENV_NAME"] missing.'
    end

    database, user, password = remote_credentials(app, variable)
    pid = start_scalingo_tunnel(app, variable)
    at_exit do
      Process.kill("INT", pid) if pid != -1
      puts '*** Tunnel closed'
    end
    puts '*** Tunnel opened'
    yield(database, user, password)
  end

  class VariableError < StandardError

  end

end
