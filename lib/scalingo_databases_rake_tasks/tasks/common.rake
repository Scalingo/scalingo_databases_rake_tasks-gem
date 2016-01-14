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
    o, thr = Open3::pipeline_r cmd
    out = ""
    while out == ""
      begin
      out = o.read_nonblock(200)
      rescue IO::EAGAINWaitReadable ; end
    end

    while !out.include?("127.0.0.1:27717") and !out.include?("address already in use")
      sleep 0.2
      begin
        out = o.read_nonblock(200)
      rescue EOFError, IO::EAGAINWaitReadable ; end
    end

    return -1 if out.include? "address already in use"
    return thr[0].pid
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
