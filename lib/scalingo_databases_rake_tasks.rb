require "scalingo_databases_rake_tasks/version"
require "rake"

module ScalingoDbTasks
  include Rake::DSL if defined? Rake::DSL
  def self.install_tasks
    tasks = ["common", "mongodb", "mysql", "postgresql"]
    tasks.each { |type| load("scalingo_databases_rake_tasks/tasks/#{type}.rake") }
  end
end

# If we are in a Rails app use Railtie to load tasks.
# Otherwise the user has to add `require "scalingo_databases_rake_tasks"` in Rakefile
if defined?(Rails)
  require "scalingo_databases_rake_tasks/railtie"
else
  ScalingoDbTasks::install_tasks
end
