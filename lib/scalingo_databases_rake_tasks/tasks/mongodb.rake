require 'active_support/core_ext/object/blank'

namespace :scalingo do
  namespace :mongodb do
    desc "Backup local MongoDB database"
    task :backup_local => :environment do
      database, user, password, host = ScalingoMongoDB.local_credentials ENV['FILE']
      ScalingoMongoDB.backup(database, user, password, host)
    end

    desc "Backup remote Scalingo MongoDB database"
    task :backup_remote do
      open_tunnel("SCALINGO_MONGO_URL") do |database, user, password|
        ScalingoMongoDB.backup(database, user, password, "127.0.0.1:27717")
      end
    end

    desc "Restore local MongoDB database using a Scalingo backup"
    task :restore_local => :environment do
      database, user, password, host = ScalingoMongoDB.local_credentials ENV['FILE']
      ScalingoMongoDB.restore(database, user, password, host)
    end

    desc "Restore remote Scalingo MongoDB database using local backup"
    task :restore_remote do
      open_tunnel("SCALINGO_MONGO_URL") do |database, user, password|
        confirm_remote(database)
        ScalingoMongoDB.restore(database, user, password, "127.0.0.1:27717")
      end
    end

    private

    module ScalingoMongoDB
      DUMP_NAME = "scalingo_mongodb_dump"

      def self.local_credentials(filename)
        filename ||= "mongoid"
        key = self.mongoid_configuration_key
        result = File.read "#{Rails.root}/config/#{filename}.yml"
        config_file = YAML::load(ERB.new(result).result)

        if config_file[Rails.env][key]['default']['uri']
          require 'uri'
          uri = URI.parse config_file[Rails.env][key]['default']['uri']

          return [
            uri.path[1..-1],
            uri.user,
            uri.password,
            "#{(uri.host || "127.0.0.1")}:#{(uri.port || "27017")}"
          ]
        else
          return [
            config_file[Rails.env][key]['default']['database'],
            config_file[Rails.env][key]['default']['username'],
            config_file[Rails.env][key]['default']['password'],
            config_file[Rails.env][key]['default']['hosts'].first || "127.0.0.1"
          ]
        end
      end

      def self.backup database, user, password, host
        if ENV["EXCLUDE_COLLECTIONS"]
          extra_args = ENV["EXCLUDE_COLLECTIONS"].split(",").map{|c| "--excludeCollection=\"#{c}\""}.join(" ")
        end
        workdir = Dir.mktmpdir("scalingo-mongodb")
        cmd = "/usr/bin/env mongodump -h #{host} -d #{database} -o #{workdir} #{extra_args}"
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
	  command << " && tar czfh #{archive_name DUMP_NAME} -C #{workdir} ."
        end

        puts "*** Executing #{output}"
        make_tmp_dir
        system(cmd)
      end

      def self.restore database, user, password, host
        workdir = Dir.mktmpdir("scalingo-mongodb")
        cmd = "tar xvzf #{archive_name DUMP_NAME} -C #{workdir}"
        cmd << " && /usr/bin/env mongorestore --drop -h #{host} --db #{database} --dir #{workdir}/*"
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

        puts "*** Executing #{output}"
        system(cmd)
        puts "*** Cleaning #{workdir}"
        FileUtils.rm_r workdir
      end

      def self.mongoid_configuration_key
        Gem::Version.new(Mongoid::VERSION) > Gem::Version.new("5.0.0") ? "clients" : "sessions"
      end
    end
  end
end
