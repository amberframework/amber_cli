require "http/headers"

headers = {"content-type" => "application/json"}
http_headers = HTTP::Headers.new
headers.each { |key, value| http_headers[key] = value }
