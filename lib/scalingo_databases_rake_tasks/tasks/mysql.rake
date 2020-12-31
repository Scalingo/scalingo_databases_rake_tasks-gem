require 'tmpdir'

namespace :scalingo do
  namespace :mysql do
    desc "Backup local MySQL database"
    task :backup_local => :environment do
      database, user, password, host, port = ScalingoMySQL.local_credentials
      ScalingoMySQL.backup(database, user, password, host, port)
    end

    desc "Backup remote Scalingo MySQL database"
    task :backup_remote do
      open_tunnel("SCALINGO_MYSQL_URL") do |database, user, password|
        ScalingoMySQL.backup(database, user, password, "127.0.0.1", 27717)
      end
    end

    desc "Restore local MySQL database using a Scalingo backup"
    task :restore_local => :environment do
      database, user, password, host, port = ScalingoMySQL.local_credentials
      ScalingoMySQL.restore(database, user, password, host, port)
    end

    desc "Restore remote Scalingo MySQL database using local backup"
    task :restore_remote do
      open_tunnel("SCALINGO_MYSQL_URL") do |database, user, password|
        confirm_remote(database)
        ScalingoMySQL.restore(database, user, password, "127.0.0.1", 27717)
      end
    end

    private

    module ScalingoMySQL
      DUMP_NAME = "scalingo_mysql_dump.sql"
      DUMP_PATH = Dir.tmpdir + "/#{DUMP_NAME}"

      def self.local_credentials
        config = ActiveRecord::Base.configurations[Rails.env]
        return [
          config['database'],
          config['username'],
          config['password'],
          config['host'] || "127.0.0.1",
          config['port'] || "3306",
        ]
      end

      def self.backup database, user, password, host, port
        base_cmd = "/usr/bin/env mysqldump --no-tablespaces --add-drop-table --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset -h #{host} -P #{port} -u #{user}"
        cmd = ""
        cmd << base_cmd
        public_cmd = ""
        public_cmd << base_cmd

        unless password.nil?
          cmd << " -p'#{password}'"
          public_cmd << " -p [password filtered]"
        end
        tar_cmd = " #{database} > #{DUMP_PATH} && tar cvzf #{archive_name DUMP_NAME} -C #{Dir.tmpdir()} #{DUMP_NAME}"
        cmd << tar_cmd
        public_cmd << tar_cmd

        puts "*** Executing #{public_cmd}"
        make_tmp_dir
        system(cmd)
      end

      def self.restore database, user, password, host, port
        base_cmd = "/usr/bin/env tar xvzOf #{archive_name DUMP_NAME} | /usr/bin/env mysql -h #{host} -P #{port} -u #{user}"
        cmd = ""
        cmd << base_cmd
        public_cmd = ""
        public_cmd << base_cmd

        unless password.nil?
          cmd << " -p'#{password}'"
          public_cmd << " -p [password filtered]"
        end
        cmd << " #{database}"
        public_cmd << " #{database}"

        puts "*** Executing #{public_cmd}"
        system(cmd)
      end
    end

  end
end
