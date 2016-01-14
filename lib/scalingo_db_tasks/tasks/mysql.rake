require 'uri'
require 'open3'

namespace :scalingo do
  namespace :mysql do
    desc "Backup Scalingo MySQL database"
    task backup: :environment do
      app = ENV["APP"]
      variable = ENV["DB_ENV_NAME"] || "SCALINGO_MYSQL_URL"
      database, user, password = find_credentials_url(app, variable)
      pid = start_scalingo_tunnel(app, variable)
      send("backup_mysql_database", database, user, password, "127.0.0.1", 27717)
      Process.kill("INT", pid) if pid != -1
    end

    desc "Restore your local MySQL database using Scalingo backup"
    task restore_locally: :environment do
      rails_env = ENV["RAILS_ENV"] || "development"
      cmd = "/usr/bin/env tar xvzf #{archive_name} && rails dbconsole -p #{rails_env} < dump.sql"
      puts cmd
      system(cmd)
    end

    desc "Restore remote Scalingo MySQL database using a local backup"
    task restore: :environment do
      app = ENV["APP"]
      variable =  ENV["DB_ENV_NAME"] || "SCALINGO_MYSQL_URL"
      database, user, password = find_credentials_url(app, variable)
      pid = start_scalingo_tunnel(app, variable)
      cmd = "/usr/bin/env tar xvzf #{archive_name} && /usr/bin/env mysql -h 127.0.0.1 -u #{user} -p#{password} -P 27717 #{database} < dump.sql"
      system(cmd)
      Process.kill("INT", pid) if pid != -1
    end

  end

  private

  def find_credentials_url app, variable
    cmd = "scalingo -a #{app} env | grep #{variable} | cut -d '=' -f2"
    output = IO.popen(cmd)
    uri = URI( output.readlines.first.strip )
    [uri.path[1..-1], uri.user, uri.password]
  end

  def start_scalingo_tunnel app, variable
    cmd = "scalingo -a #{app} db-tunnel -p 27717 #{variable}"
    puts "*** executing #{cmd}"
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

  def archive_name
    "#{Rails.root}/tmp/dump.tar.gz"
  end

  def backup_mysql_database database, user, password, host, port
    cmd = "/usr/bin/env mysqldump --add-drop-table --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset -h #{host} -P #{port} -u #{user} "
    puts cmd + "... [password filtered]"
    cmd << " -p'#{password}' " unless password.nil?
    cmd << " #{database} > dump.sql && tar cvzf #{archive_name} dump.sql"
    puts "*** executing #{cmd}"
    system(cmd)
  end
end
