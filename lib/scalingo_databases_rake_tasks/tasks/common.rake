require 'uri'
require 'open3'
require 'timeout'

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

  def archive_contain_sql path
    `tar tf #{path} | grep "\.sql$" | wc -l`.to_i > 0
  end

  def make_tmp_dir
    FileUtils.mkdir_p 'tmp'
  end

  def remote_credentials app, variable
    output = `scalingo -a #{app} env | grep "^#{variable}=" | cut -d '=' -f2 | tr -d '\n'`
    uri = URI(output.strip)
    if uri.to_s.blank?
      raise VariableError, "Environment variable #{variable} not found."
    else
      [uri.path[1..-1], uri.user, uri.password]
    end
  end

  def start_scalingo_tunnel app, variable
    if ENV['SSH_IDENTITY']
      cmd = "scalingo -a #{app} db-tunnel -i #{ENV['SSH_IDENTITY']} -p 27717 #{variable}"
    else
      cmd = "scalingo -a #{app} db-tunnel -p 27717 #{variable}"
    end
    puts "*** Executing #{cmd}"
    i, o, thr = Open3::pipeline_rw cmd
    pid = thr[0].pid
    puts '*** Tunnel opened'

    close_tunnel = lambda {
      if thr[0].status
        thr[0].kill
        Process.kill("INT", pid) if pid != -1
        puts '*** Tunnel closed'
      end
    }
    at_exit do
      close_tunnel.call
    end

    loop do
      read_line(o) do |line|
        # puts line # debug
        if line.include?("Encrypted")
          abort "*** Your SSH key is encrypted. This gem is only compatible with SSH agents or unencrypted keys."
        end

        if line.include?("An error occured")
          abort "*** #{line}"
        end

        if line.include?("address already in use")
          abort "*** Address 127.0.0.1:27717 is already in use."
        end

        if line.include?("'127.0.0.1:27717'")
          return [pid, close_tunnel]
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
      abort "Environment variable APP not found."
    end
    unless variable
      abort "Environment variable DB_ENV_NAME not found."
    end

    database, user, password = remote_credentials(app, variable)

    begin
      pid, close_tunnel = Timeout::timeout(15) do
        start_scalingo_tunnel(app, variable)
      end
    rescue Timeout::Error => e
      abort "*** Error in tunnel: #{e}"
    end

    yield(database, user, password)
    close_tunnel.call
  end

  class VariableError < StandardError

  end

end
