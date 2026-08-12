require "json"

if ARGV.size < 2
  STDERR.puts "usage: read_asset_paths MANIFEST LOGICAL_PATH [LOGICAL_PATH ...]"
  exit 64
end

manifest_path = ARGV.shift
manifest = JSON.parse(File.read(manifest_path))
assets = manifest["assets"].as_h

ARGV.each do |logical_path|
  entry = assets[logical_path]? || raise "Asset #{logical_path.inspect} is missing from #{manifest_path}"
  puts entry["path"].as_s
end
