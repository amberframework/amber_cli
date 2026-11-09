require "../spec_helper"

describe AmberCLI::Commands::DatabaseCommand do
  describe ".connection_url_for_migrations" do
    it "points the migration driver at the socket file of a socket directory URL" do
      url = "postgres:///app_production?host=/var/run/postgresql"
      expected = URI.parse("postgres:///app_production?host=#{URI.encode_www_form("/var/run/postgresql/.s.PGSQL.5432")}").to_s

      AmberCLI::Commands::DatabaseCommand.connection_url_for_migrations(url).should eq(expected)
    end

    it "leaves a URL that already names the socket file alone" do
      url = "postgres:///app?host=/tmp/.s.PGSQL.5432"
      AmberCLI::Commands::DatabaseCommand.connection_url_for_migrations(url).should eq(url)
    end

    it "leaves non-socket URLs alone" do
      tcp_url = "postgres://localhost:5432/app"
      sqlite_url = "sqlite3:./db/app.db"
      AmberCLI::Commands::DatabaseCommand.connection_url_for_migrations(tcp_url).should eq(tcp_url)
      AmberCLI::Commands::DatabaseCommand.connection_url_for_migrations(sqlite_url).should eq(sqlite_url)
    end
  end
end
