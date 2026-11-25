require "../spec_helper"

private CREATE_POSTS_MIGRATION = <<-SQL
  -- +micrate Up
  CREATE TABLE posts (id INTEGER NOT NULL PRIMARY KEY, title VARCHAR);

  -- +micrate Down
  DROP TABLE IF EXISTS posts;
  SQL

private CREATE_COMMENTS_MIGRATION = <<-SQL
  -- +micrate Up
  -- +micrate StatementBegin
  CREATE TABLE comments (id INTEGER NOT NULL PRIMARY KEY, body TEXT);
  -- +micrate StatementEnd
  INSERT INTO comments (id, body) VALUES (1, 'first; with a semicolon');

  -- +micrate Down
  DROP TABLE IF EXISTS comments;
  SQL

# The table Micrate (amberframework/micrate 56afd560) creates on SQLite, and
# the rows it writes: `src/micrate/db/sqlite3.cr`.
private MICRATE_SQLITE_TABLE = <<-SQL
  CREATE TABLE micrate_db_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version_id INTEGER NOT NULL,
    is_applied INTEGER NOT NULL,
    tstamp TIMESTAMP
  );
  SQL

private POSTS_VERSION    = 20240101120000_i64
private COMMENTS_VERSION = 20240102120000_i64

private def with_migrations_directory(&)
  root = File.join(Dir.tempdir, "amber_db_spec_#{Random::Secure.hex(6)}")
  migrations_directory = File.join(root, "db", "migrations")
  Dir.mkdir_p(migrations_directory)
  File.write(File.join(migrations_directory, "#{POSTS_VERSION}_create_posts.sql"), CREATE_POSTS_MIGRATION)
  File.write(File.join(migrations_directory, "#{COMMENTS_VERSION}_create_comments.sql"), CREATE_COMMENTS_MIGRATION)
  yield root, migrations_directory, "sqlite3:#{File.join(root, "db", "app_development.db")}"
ensure
  FileUtils.rm_rf(root) if root
end

private def run_database_task(action : String, database_url : String, migrations_directory : String,
                              environment : String = "development") : String
  output = IO::Memory.new
  AmberCLI::Database::RunDatabaseTask.new(action, database_url, environment, migrations_directory, output).perform
  output.to_s
end

private def list_of_tables(database_url : String) : Array(String)
  DB.open(database_url) do |database|
    database.query_all("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name", as: String)
  end
end

private def micrate_rows(database_url : String) : Array({Int64, Int64})
  DB.open(database_url) do |database|
    database.query_all("SELECT version_id, is_applied FROM micrate_db_version ORDER BY id", as: {Int64, Int64})
  end
end

describe AmberCLI::Database::RunDatabaseTask do
  describe ".handles?" do
    it "runs the migration and maintenance actions" do
      %w[create drop migrate rollback redo status version].each do |action|
        AmberCLI::Database::RunDatabaseTask.handles?(action).should be_true
      end
    end

    it "leaves seed, connect, and unknown actions to the command" do
      %w[seed connect upgrade].each do |action|
        AmberCLI::Database::RunDatabaseTask.handles?(action).should be_false
      end
    end
  end

  describe "#perform" do
    it "raises for an unknown action" do
      expect_raises(AmberCLI::Database::UnknownDatabaseActionError, "Unknown command: upgrade") do
        AmberCLI::Database::RunDatabaseTask.new("upgrade", "sqlite3:./db/never.db", "development").perform
      end
    end

    it "creates and drops a SQLite database file" do
      with_migrations_directory do |root, migrations_directory, database_url|
        path = File.join(root, "db", "app_development.db")

        run_database_task("create", database_url, migrations_directory).should contain("Created database")
        File.exists?(path).should be_true
        run_database_task("create", database_url, migrations_directory).should contain("already exists")

        run_database_task("drop", database_url, migrations_directory).should contain("Dropped database")
        File.exists?(path).should be_false
      end
    end

    it "refuses to drop a production database" do
      with_migrations_directory do |root, migrations_directory, database_url|
        run_database_task("create", database_url, migrations_directory, "production")

        expect_raises(Grant::Schema::ProtectedEnvironmentError) do
          run_database_task("drop", database_url, migrations_directory, "production")
        end
        File.exists?(File.join(root, "db", "app_development.db")).should be_true
      end
    end

    it "migrates, reports status and version, rolls back, and redoes Micrate .sql files" do
      with_migrations_directory do |_root, migrations_directory, database_url|
        status = run_database_task("status", database_url, migrations_directory)
        status.should contain(AmberCLI::Database::RunDatabaseTask::STATUS_HEADER)
        status.should contain("Pending                  -- #{POSTS_VERSION}_create_posts.sql")

        run_database_task("migrate", database_url, migrations_directory)
        list_of_tables(database_url).should contain("comments")
        DB.open(database_url) { |database| database.scalar("SELECT body FROM comments").should eq("first; with a semicolon") }
        run_database_task("version", database_url, migrations_directory).strip.should eq(COMMENTS_VERSION.to_s)
        run_database_task("migrate", database_url, migrations_directory).should contain("No migrations to run")

        status = run_database_task("status", database_url, migrations_directory)
        status.should_not contain("Pending")
        status.should contain("-- #{COMMENTS_VERSION}_create_comments.sql")

        run_database_task("rollback", database_url, migrations_directory)
        list_of_tables(database_url).should_not contain("comments")
        run_database_task("version", database_url, migrations_directory).strip.should eq(POSTS_VERSION.to_s)
        run_database_task("status", database_url, migrations_directory).should contain("Pending                  -- #{COMMENTS_VERSION}_create_comments.sql")

        run_database_task("migrate", database_url, migrations_directory)
        run_database_task("redo", database_url, migrations_directory)
        list_of_tables(database_url).should contain("comments")
        micrate_rows(database_url).last(3).should eq([{COMMENTS_VERSION, 1_i64}, {COMMENTS_VERSION, 0_i64}, {COMMENTS_VERSION, 1_i64}])
      end
    end

    it "continues a database Micrate migrated without running its versions again" do
      with_migrations_directory do |_root, migrations_directory, database_url|
        # The state Micrate leaves after `amber db migrate` ran the first
        # migration: its version table with its seed row and one applied row.
        Dir.mkdir_p(File.dirname(database_url.lchop("sqlite3:")))
        DB.open(database_url) do |database|
          database.exec MICRATE_SQLITE_TABLE
          database.exec "INSERT INTO micrate_db_version (version_id, is_applied, tstamp) VALUES (0, 1, '2026-11-01 09:30:00.000')"
          database.exec "CREATE TABLE posts (id INTEGER NOT NULL PRIMARY KEY, title VARCHAR)"
          database.exec "INSERT INTO posts (id, title) VALUES (7, 'kept')"
          database.exec "INSERT INTO micrate_db_version (version_id, is_applied, tstamp) VALUES (#{POSTS_VERSION}, 1, '2026-11-01 09:30:01.000')"
        end

        status = run_database_task("status", database_url, migrations_directory)
        status.should contain("2026-11-01 09:30:01.000  -- #{POSTS_VERSION}_create_posts.sql")
        status.should contain("Pending                  -- #{COMMENTS_VERSION}_create_comments.sql")

        output = run_database_task("migrate", database_url, migrations_directory)
        output.should contain("CreateComments")
        output.should_not contain("CreatePosts")

        DB.open(database_url) { |database| database.scalar("SELECT title FROM posts WHERE id = 7").should eq("kept") }
        list_of_tables(database_url).should_not contain("schema_migrations")
        micrate_rows(database_url).should eq([{0_i64, 1_i64}, {POSTS_VERSION, 1_i64}, {COMMENTS_VERSION, 1_i64}])
        run_database_task("version", database_url, migrations_directory).strip.should eq(COMMENTS_VERSION.to_s)
      end
    end
  end
end
