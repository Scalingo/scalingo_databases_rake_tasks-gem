# ScalingoDatabasesRakeTasks

A gem providing rake tasks such as **backup** and **restore** for database manipulations on [Scalingo](https://scalingo.com/).

Currently supported databases:
- MongoDB
- MySQL
- PostgreSQL

Available tasks for **each** database:
- `backup_local`: make a backup of local database
- `backup_remote`: make a backup of remote Scalingo database
- `restore_local`: restore a local database with an archive
- `restore_remote`: restore a remote Scalingo database with an archive

## Usage

For remote operations you will have to set your shell's environment variable `APP` as your app name on Scalingo. The variable `DB_ENV_NAME` is optional, by default it will be the one generated when you provisionned the database addon. For example, if your database is a MongoDB then the variable will be `SCALINGO_MONGO_URL`.

### Available Env Vars

Global:
- `APP`: Scalingo app name (mandatory)
- `DB_ENV_NAME`: Scalingo database connection var name, e.g. `SCALINGO_MONGO_URL` (optional)
- `SSH_IDENTITY`: specify a SSH identity file, e.g. `~/.ssh/id_rsa` (optional)

MongoDB:
- `FILE`: your database config file name, e.g. `database` (optional)

PostgreSQL:
- `PG_DUMP_CMD`: specify the path or command name of the tool to use, default: `pg_dump` (optional)
- `PG_RESTORE_CMD`:specify the path or command name of the tool to use, default: `pg_restore` (optional)

### Commands

To see the complete list of tasks: `rake -T scalingo`

Example of commands for MongoDB:
- `rake scalingo:mongodb:backup_local`
- `rake scalingo:mongodb:backup_remote`
- `rake scalingo:mongodb:restore_local`
- `rake scalingo:mongodb:restore_remote`

### Backup and Restore

Backups are stored under the `tmp` folder of your project, the database type is part of the archive name (e.g. scalingo_mongodb_dump.tar.gz).

To restore from a specific archive, you'll have to give it the default archive name and put it inside of `tmp` folder before running the rake command.

### SSH Identity

If you are not using a SSH agent and your default SSH identity file is not `id_rsa` you can specify your custom identity file path with the `SSH_IDENTITY` variable.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scalingo_databases_rake_tasks'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install scalingo_databases_rake_tasks

For Rails apps nothing to do.

For other apps, add `require "scalingo_databases_rake_tasks"` to your Rakefile.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Scalingo/scalingo_databases_rake_tasks-gem.

