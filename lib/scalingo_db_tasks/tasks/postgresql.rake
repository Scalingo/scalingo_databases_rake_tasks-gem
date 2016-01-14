require 'uri'
require 'open3'

namespace :scalingo do
  namespace :postgresql do
    desc "Dump schema and data to a gzip file"
    task :backup => :environment do
      pgurl = URI(`scalingo -a scalingo-cockpit-api-staging env | grep SCALINGO_POSTGRESQL_URL= | cut -d '=' -f2 | tr -d '\n'`)
      database = pgurl.path[1..-1]
      pid = start_scalingo_tunnel
      sleep 5
      send("backup_postgresql_database", database, pgurl.user, pgurl.password, "127.0.0.1:27717")
      Process.kill("INT", pid) if pid != -1
    end

    desc "Load schema and data from a gzip file"
    task :restore => :environment do
      type, database, user, password, host = retrieve_db_info ENV['FILE']
      type = "mysql" if type == "mysql2"
      if type == "mongodb" || type == "postgresql"
        send("restore_#{type}_database", database, user, password, host)
      else
        send("drop_#{type}_database", database, user, password, host)
        send("create_#{type}_database", database, user, password, host)
        send("restore_#{type}_database", database, user, password, host)

        #Rake::Task['db:migrate'].invoke
      end
    end

    private

    def start_scalingo_tunnel
      o, thr = Open3::pipeline_r "scalingo -a scalingo-cockpit-api-staging db-tunnel -p 27717 DATABASE_URL"
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
      "#{Rails.root}/db/dump.tar.gz"
    end

     def retrieve_db_info(filename)
      # filename = "mongoid" if File.exists?("#{Rails.root}/config/mongoid.yml")
      filename ||= "database"
      result = File.read "#{Rails.root}/config/#{filename}.yml"
      # result.strip!
      config_file = YAML::load(ERB.new(result).result)
      type = filename == "mongoid" ? "mongodb" : config_file[Rails.env]['adapter']
      if type == "mongodb"
        if config_file[Rails.env]['sessions']['default']['uri']
          require 'uri'
          uri = URI.parse config_file[Rails.env]['sessions']['default']['uri']

          return [type, uri.path[1..-1], uri.user, uri.password, (uri.host || "127.0.0.1")]
        else
          return [
            type,
            config_file[Rails.env]['sessions']['default']['database'],
            config_file[Rails.env]['sessions']['default']['username'],
            config_file[Rails.env]['sessions']['default']['password'],
            config_file[Rails.env]['sessions']['default']['hosts'].first || "127.0.0.1"
          ]
        end
      end

      return [
        type,
        config_file[Rails.env]['database'],
        config_file[Rails.env]['username'],
        config_file[Rails.env]['password'],
        config_file[Rails.env]['hosts'].try!(:first) || "127.0.0.1:5432",
      ]
    end

    def backup_postgresql_database database, user, password, hostport
      host, port = hostport.split(":")
      user_cmd = ""
      password_cmd = ""
      if not user.blank?
        user_cmd = " -U #{user}"
        if not password.blank?
          password_cmd = "PGPASSWORD=#{password}"
        end
      end
      base_cmd = "pg_dump -O -n public --format=c #{user_cmd} -h #{host} -p #{port} -d #{database}"
      output = "rm -rf dump/ 2>/dev/null && /usr/bin/env PGPASSWORD=[FILTERED] #{base_cmd}"
      cmd = "rm -rf dump/ 2>/dev/null && /usr/bin/env #{password_cmd} #{base_cmd}"

      [cmd, output].each do |command|
        command << " | gzip -c > #{archive_name}"
      end

      puts output
      system(cmd)
    end

    def restore_postgresql_database database, user, password, hostport
      host, port = hostport.split(":")
      user_cmd = ""
      password_cmd = ""
      if not user.blank?
        user_cmd = " -U #{user}"
        if not password.blank?
          password_cmd = "PGPASSWORD=#{password}"
        end
      end

      base_cmd = "rm -rf dump/ 2>/dev/null && gunzip -c #{archive_name} | "
      pg_cmd = "pg_restore --clean #{user_cmd} -h #{host} -p #{port} -d #{database}"
      output = "#{base_cmd} PGPASSWORD=[FILTERED] #{pg_cmd}"
      cmd = "#{base_cmd} #{password_cmd} #{pg_cmd}"
      puts output
      system(cmd)
    end
  end
end
