require "rails"
require "scalingo_db_tasks"

module Rails
  module ScalingoDbTasks
    class Railtie < Rails::Railtie
      rake_tasks do
        ScalingoDbTasks::install_tasks
      end
    end
  end
end
