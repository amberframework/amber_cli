require "grant"
# The same drivers a generated application uses: Grant's PostgreSQL driver
# and crystal-mysql, both on Beryl TLS 1.3 (no OpenSSL), and Grant's SQLite
# driver on the system's libsqlite3, which `amber new -d sqlite` apps use in
# 2.0.17. Grant's own SQLite engine follows when generated apps move to it.
require "grant/adapter/pg"
require "grant/adapter/mysql"
require "grant/adapter/sqlite"

module AmberCLI::Database
  # Raised for an action `amber database` does not know.
  class UnknownDatabaseActionError < Exception
    def initialize(action : String)
      super("Unknown command: #{action}")
    end
  end

  # Runs one `amber database` action against an application's database on
  # `Grant::Tasks::Database`.
  #
  # Versions are kept in Micrate's `micrate_db_version` table
  # (`Grant::Schema::Tracking::Micrate`), so a database Micrate migrated keeps
  # its history, and every `db/migrations/*.sql` file with `-- +micrate Up` and
  # `-- +micrate Down` sections runs unchanged.
  #
  # ```
  # AmberCLI::Database::RunDatabaseTask.new("migrate", "sqlite3:./db/blog_development.db", "development").perform
  # ```
  class RunDatabaseTask
    LIST_OF_ACTIONS = %w[create drop migrate rollback redo status version]

    STATUS_HEADER    = "Applied At                  Migration"
    STATUS_SEPARATOR = "======================================="

    getter action : String
    getter database_url : String
    getter environment : String
    getter migrations_directory : String

    @database_tasks : Grant::Tasks::Database?

    def initialize(@action : String, @database_url : String, @environment : String,
                   @migrations_directory : String = "./db/migrations", @output : IO = STDOUT)
    end

    # True when *action* is one this task runs.
    def self.handles?(action : String) : Bool
      LIST_OF_ACTIONS.includes?(action)
    end

    def perform : Nil
      case @action
      when "create"   then create_database
      when "drop"     then drop_database
      when "migrate"  then migrate_database
      when "rollback" then roll_back_last_migration
      when "redo"     then redo_last_migration
      when "status"   then print_migration_status
      when "version"  then print_current_version
      else                 raise UnknownDatabaseActionError.new(@action)
      end
    end

    # The Grant tasks for this database, built once per action.
    def database_tasks : Grant::Tasks::Database
      @database_tasks ||= Grant::Tasks::Database.new(
        @database_url, @environment,
        migrations: [] of Grant::Schema::MigrationEntry,
        migration_paths: [@migrations_directory],
        tracking: Grant::Schema::Tracking::Micrate,
        output: @output)
    end

    private def create_database : Nil
      if database_tasks.create
        @output.puts "Created database #{database_label}"
      else
        @output.puts "Database #{database_label} already exists"
      end
    end

    # `Grant::Tasks::Database#drop` refuses a protected environment
    # (production) with `Grant::Schema::ProtectedEnvironmentError`.
    private def drop_database : Nil
      if database_tasks.drop
        @output.puts "Dropped database #{database_label}"
      else
        @output.puts "Database #{database_label} does not exist"
      end
    end

    private def migrate_database : Nil
      list_of_versions_run = database_tasks.migrate
      if list_of_versions_run.empty?
        @output.puts "No migrations to run. Current version: #{database_tasks.version}"
      end
    end

    private def roll_back_last_migration : Nil
      list_of_versions_run = database_tasks.rollback(1)
      if list_of_versions_run.empty?
        @output.puts "No migrations to roll back. Current version: #{database_tasks.version}"
      end
    end

    # Rolls the newest migration back and runs it again.
    private def redo_last_migration : Nil
      list_of_versions_run = database_tasks.migration_context.redo(1)
      if list_of_versions_run.empty?
        @output.puts "No migrations to redo. Current version: #{database_tasks.version}"
      end
    end

    # Prints Micrate's status table: when each migration was applied, or
    # `Pending`.
    private def print_migration_status : Nil
      applied_at_by_version = read_applied_timestamps
      file_name_by_version = read_migration_file_names
      @output.puts STATUS_HEADER
      @output.puts STATUS_SEPARATOR
      database_tasks.status.each do |migration_status|
        applied_at = applied_at_by_version[migration_status.version]? || "Applied"
        state = migration_status.applied? ? applied_at : "Pending"
        file_name = file_name_by_version[migration_status.version]? || "#{migration_status.version} #{migration_status.name}"
        @output.puts "%-24s -- %s" % [state, file_name]
      end
    end

    private def print_current_version : Nil
      @output.puts database_tasks.version
    end

    # The `tstamp` of each applied version's newest row in `micrate_db_version`.
    # Rows Grant writes on SQLite have no timestamp; those show as `Applied`.
    private def read_applied_timestamps : Hash(Int64, String)
      applied_at_by_version = {} of Int64 => String
      adapter = database_tasks.adapter
      tracking_table = Grant::Schema::SchemaMigration.new(adapter, Grant::Schema::Tracking::Micrate)
      return applied_at_by_version unless tracking_table.table_exists?

      list_of_seen_versions = Set(Int64).new
      sql = "SELECT version_id, is_applied, tstamp FROM #{Grant::Schema::SchemaMigration::MICRATE_TABLE} ORDER BY id DESC"
      adapter.open(sql) do |database|
        database.query_each(sql) do |result_set|
          version = result_set.read(Int64)
          applied_flag = result_set.read
          applied_at = result_set.read
          next unless list_of_seen_versions.add?(version)
          next unless applied_flag == true || applied_flag == 1
          if timestamp = format_timestamp(applied_at)
            applied_at_by_version[version] = timestamp
          end
        end
      end
      applied_at_by_version
    end

    private def format_timestamp(value) : String?
      if value.is_a?(Time)
        value.to_s("%Y-%m-%d %H:%M:%S %:z")
      elsif value.is_a?(String)
        value.presence
      end
    end

    private def read_migration_file_names : Hash(Int64, String)
      file_name_by_version = {} of Int64 => String
      Dir.glob(File.join(@migrations_directory, "*.sql")).each do |path|
        file_name = File.basename(path)
        if version = file_name.split('_', 2).first.to_i64?
          file_name_by_version[version] = file_name
        end
      end
      file_name_by_version
    end

    # The database name or SQLite file, without credentials.
    private def database_label : String
      Grant::Adapter::Registry.redact(@database_url)
    end
  end
end
