namespace :scalingo do
  namespace :postgresql do
    desc "Backup local PostgreSQL database"
    task :backup_local => :environment do
      database, user, password, host, port = ScalingoPostgreSQL.local_credentials
      ScalingoPostgreSQL.backup(database, user, password, host, port)
    end

    desc "Backup remote Scalingo PostgreSQL database"
    task :backup_remote => :environment do
      open_tunnel("SCALINGO_POSTGRESQL_URL") do |database, user, password|
        ScalingoPostgreSQL.backup(database, user, password, "127.0.0.1", "27717")
      end
    end

    desc "Restore local PostgreSQL database using a Scalingo backup"
    task :restore_local => :environment do
      database, user, password, host, port = ScalingoPostgreSQL.local_credentials
      ScalingoPostgreSQL.restore(database, user, password, host, port)
    end

    desc "Restore remote Scalingo PostgreSQL database using local backup"
    task :restore_remote => :environment do
      open_tunnel("SCALINGO_POSTGRESQL_URL") do |database, user, password|
        confirm_remote(database)
        ScalingoPostgreSQL.restore(database, user, password, "127.0.0.1", "27717")
      end
    end

    private

    module ScalingoPostgreSQL
      DUMP_NAME = "scalingo_postgresql_dump"
      DUMP_PATH = Dir.tmpdir() + "/#{DUMP_NAME}"

      def self.local_credentials
        config = ActiveRecord::Base.configurations[Rails.env]
        return [
          config['database'],
          config['username'],
          config['password'],
          config['host'] || "127.0.0.1",
          config['port'] || "5432",
        ]
      end

      def self.backup database, user, password, host, port
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

      def self.restore database, user, password, host, port
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
