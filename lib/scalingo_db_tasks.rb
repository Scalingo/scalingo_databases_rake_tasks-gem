require "scalingo_db_tasks/version"
require "rake"

module ScalingoDbTasks
  include Rake::DSL if defined? Rake::DSL
  def self.install_tasks
    FileList["lib/scalingo_db_tasks/tasks/*.rake"].each { |ext| load(ext) }
  end
end

# If we are in a Rails app use Railtie to load tasks.
# Otherwise the user has to add `require "scalingo_db_tasks"` in Rakefile
if defined?(Rails)
  require "scalingo_db_tasks/railtie"
else
  ScalingoDbTasks::install_tasks
end
