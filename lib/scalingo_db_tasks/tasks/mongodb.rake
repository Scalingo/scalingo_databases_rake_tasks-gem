require 'uri'
require 'open3'

namespace :scalingo do
  namespace :mongodb do
    desc "Dump schema and data to a gzip file"
    task :backup => :environment do
      mongo_url = URI(`scalingo -a scalingo-api-production env | grep MONGO_URL | cut -d '=' -f2 | tr -d '\n'`)
      database = mongo_url.path[1..-1]
      pid = start_scalingo_tunnel
      sleep 10
      send("backup_mongodb_database", database, mongo_url.user, mongo_url.password, "127.0.0.1:27717")
      Process.kill("INT", pid) if pid != -1
    end

    desc "Load schema and data from a gzip file"
    task :restore => :environment do
      type, database, user, password, host = retrieve_db_info ENV['FILE']
      type = "mysql" if type == "mysql2"
      if type == "mongodb"
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
      o, thr = Open3::pipeline_r "scalingo -a scalingo-api-production db-tunnel -p 27717 MONGO_URL"
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
      filename = "mongoid" if File.exists?("#{Rails.root}/config/mongoid.yml")
      filename ||= "database"
      result = File.read "#{Rails.root}/config/#{filename}.yml"
      # result.strip!
      config_file = YAML::load(ERB.new(result).result)
      type = filename == "mongoid" ? "mongodb" : config_file[Rails.env]['adapter']
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

    def backup_mongodb_database database, user, password, host
      cmd = "rm -rf dump/ 2>/dev/null && /usr/bin/env mongodump --numThreads 1 -h #{host} -d #{database}"
      if user.blank?
        output = cmd
      else
        cmd << " -u #{user}"
        if password.blank?
          output = cmd
        else
          cmd << " --password"
          output = "#{cmd} ... [password filtered]"
          cmd << " #{password}"
        end
      end

      [cmd, output].each do |command|
        command << " && tar czfh #{archive_name} dump/"
      end

      puts output
      system(cmd)
    end

    def restore_mongodb_database database, user, password, host
      cmd = "rm -rf dump/ 2>/dev/null && tar xvzf #{archive_name}"
      cmd += " && /usr/bin/env mongorestore --drop -h #{host} -d #{database} --dir dump/*"
      if user.blank?
        puts cmd
      else
        cmd << " -u #{user}"
        if password.blank?
          puts cmd
        else
          cmd << " --password"
          puts "#{cmd} ... [password filtered]"
          cmd << " #{password}"
        end
      end

      system(cmd)
    end
  end
end
