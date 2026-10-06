queries = ["SELECT 1", "INSERT INTO things"]
queries.count { |query| query.includes?("SELECT") || query.includes?("INSERT") }
