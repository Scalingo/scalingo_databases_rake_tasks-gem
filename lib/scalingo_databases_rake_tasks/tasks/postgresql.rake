namespace :scalingo do
  namespace :postgresql do
    desc "Backup local PostgreSQL database"
    task :backup_local => :environment do
      database, user, password, host = ScalingoPostgreSQL.local_credentials ENV['FILE']
      ScalingoPostgreSQL.backup(database, user, password, host)
    end

    desc "Backup remote Scalingo PostgreSQL database"
    task :backup_remote => :environment do
      open_tunnel("SCALINGO_POSTGRESQL_URL") do |database, user, password|
        ScalingoPostgreSQL.backup(database, user, password, "127.0.0.1:27717")
      end
    end

    desc "Restore local PostgreSQL database using a Scalingo backup"
    task :restore_local => :environment do
      database, user, password, host = ScalingoPostgreSQL.local_credentials ENV['FILE']
      ScalingoPostgreSQL.restore(database, user, password, host)
    end

    desc "Restore remote Scalingo PostgreSQL database using local backup"
    task :restore_remote => :environment do
      open_tunnel("SCALINGO_POSTGRESQL_URL") do |database, user, password|
        confirm_remote(database)
        ScalingoPostgreSQL.restore(database, user, password, "127.0.0.1:27717")
      end
    end

    private

    module ScalingoPostgreSQL
      DUMP_NAME = "scalingo_postgresql_dump"
      DUMP_PATH = Dir.tmpdir() + "/#{DUMP_NAME}"

      def self.local_credentials(filename)
        filename ||= "database"
        result = File.read "#{Rails.root}/config/#{filename}.yml"
        config_file = YAML::load(ERB.new(result).result)

        return [
          config_file[Rails.env]['database'],
          config_file[Rails.env]['username'],
          config_file[Rails.env]['password'],
          config_file[Rails.env]['hosts'].try!(:first) || "127.0.0.1:5432",
        ]
      end

      def self.backup database, user, password, hostport
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
        output = "rm -rf #{DUMP_PATH} 2>/dev/null && /usr/bin/env PGPASSWORD=[FILTERED] #{base_cmd}"
        cmd = "rm -rf #{DUMP_PATH} 2>/dev/null && /usr/bin/env #{password_cmd} #{base_cmd}"

        [cmd, output].each do |command|
          command << " > #{DUMP_PATH} && tar cvzf #{archive_name DUMP_NAME} -C #{Dir.tmpdir()} #{DUMP_NAME}"
        end

        puts "*** Executing #{output}"
        system(cmd)
      end

      def self.restore database, user, password, hostport
        host, port = hostport.split(":")
        user_cmd = ""
        password_cmd = ""
        if not user.blank?
          user_cmd = " -U #{user}"
          if not password.blank?
            password_cmd = "PGPASSWORD=#{password}"
          end
        end

        base_cmd = "tar xvzOf #{archive_name DUMP_NAME} | "
        pg_cmd = "pg_restore -O -n public --clean #{user_cmd} -h #{host} -p #{port} -d #{database}"
        output = "#{base_cmd} PGPASSWORD=[FILTERED] #{pg_cmd}"
        cmd = "#{base_cmd} #{password_cmd} #{pg_cmd}"

        puts "*** Executing #{output}"
        system(cmd)
      end
    end

  end
end
