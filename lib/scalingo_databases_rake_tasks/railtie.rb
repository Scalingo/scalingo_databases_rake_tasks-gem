require "rails"
require "scalingo_databases_rake_tasks"

module Rails
  module ScalingoDbTasks
    class Railtie < Rails::Railtie
      rake_tasks do
        ::ScalingoDbTasks::install_tasks
      end
    end
  end
end
