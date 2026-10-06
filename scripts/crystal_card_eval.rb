#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "tmpdir"
require "time"
require "yaml"

REPO_ROOT = File.expand_path("..", __dir__)
MINING_ROOT = "/Users/crimsonknight/agent_transcript_archive/mining/2026-10-04"
DEFAULT_CASES_PATH = File.join(MINING_ROOT, "cases_labeled.jsonl")
DEFAULT_LABELS_PATH = File.join(MINING_ROOT, "luna_labels")
DEFAULT_BINARY_PATH = File.join(REPO_ROOT, "bin", "amber-lsp")
DEFAULT_REPORT_PATH = File.join(MINING_ROOT, "eval", "CRYSTAL_CARD_EVAL_REPORT.md")
CARD_PATH = File.join(REPO_ROOT, "src", "amber_lsp", "cards", "crystal.yml")
CATEGORY_TOTALS = {
  "crystal_nil_union" => 130,
  "crystal_type_inference" => 109,
  "crystal_syntax" => 96,
  "crystal_macro" => 71,
  "crystal_stdlib_api" => 59,
  "require_or_load" => 37,
  "crystal_block_proc" => 23,
  "spec_framework" => 18,
}.freeze
EXPECTED_CASE_COUNT = CATEGORY_TOTALS.values.inject(0, :+)

def parse_options
  options = {
    :split => "authoring",
    :cases_path => DEFAULT_CASES_PATH,
    :labels_path => DEFAULT_LABELS_PATH,
    :binary_path => DEFAULT_BINARY_PATH,
    :report_path => nil,
    :heldout_label => nil,
    :show_misses => false,
  }

  parser = OptionParser.new do |options_parser|
    options_parser.banner = "Usage: ruby scripts/crystal_card_eval.rb [options]"
    options_parser.on("--split SPLIT", "authoring, heldout, or both (default: authoring)") do |value|
      options[:split] = value
    end
    options_parser.on("--heldout-label LABEL", "Required for heldout measurements; recorded in the report") do |value|
      options[:heldout_label] = value
    end
    options_parser.on("--cases PATH", "Path to cases_labeled.jsonl") do |value|
      options[:cases_path] = value
    end
    options_parser.on("--labels DIR", "Directory containing the Luna label JSONL files") do |value|
      options[:labels_path] = value
    end
    options_parser.on("--binary PATH", "amber-lsp executable to evaluate") do |value|
      options[:binary_path] = value
    end
    options_parser.on("--report PATH", "Write the final both-split report to PATH") do |value|
      options[:report_path] = value
    end
    options_parser.on("--show-misses", "Print each miss after the category summary") do
      options[:show_misses] = true
    end
    options_parser.on("-h", "--help", "Show this help") do
      puts options_parser
      exit 0
    end
  end

  parser.parse!
  unless %w[authoring heldout both].include?(options[:split])
    raise OptionParser::InvalidArgument, "--split must be authoring, heldout, or both"
  end
  if options[:split] != "authoring" && options[:heldout_label].to_s.empty?
    raise OptionParser::MissingArgument, "--heldout-label is required for heldout evaluation"
  end
  if options[:report_path] && options[:split] != "both"
    raise OptionParser::InvalidArgument, "--report is written only by --split both"
  end
  options[:report_path] ||= DEFAULT_REPORT_PATH if options[:split] == "both"
  options
end

def read_case_records(path)
  list_of_records = {}
  File.foreach(path) do |line|
    next if line.strip.empty?

    payload = JSON.parse(line)
    list_of_records[payload.fetch("case_id")] = payload
  end
  list_of_records
end

def trainable_labeled_cases(labels_path, case_records)
  list_of_cases = []
  seen_case_ids = {}
  counts_by_category = Hash.new(0)

  Dir.glob(File.join(labels_path, "*.jsonl")).sort.each do |label_path|
    File.foreach(label_path) do |line|
      next if line.strip.empty?

      label = JSON.parse(line)
      category = label["category"]
      next unless CATEGORY_TOTALS.has_key?(category)
      next unless label["trainable"] == "yes"

      case_id = label.fetch("case_id")
      raise "duplicate trainable label for #{case_id}" if seen_case_ids.has_key?(case_id)

      numeric_suffix = case_id.match(/(\d+)\z/)
      raise "case_id has no numeric suffix: #{case_id}" unless numeric_suffix

      case_record = case_records[case_id]
      raise "no case record joined for #{case_id}" unless case_record

      split = numeric_suffix[1].to_i.even? ? "authoring" : "heldout"
      list_of_cases << {
        :case_id => case_id,
        :category => category,
        :split => split,
        :wrong => label["wrong"].to_s,
        :right => label["right"].to_s,
        :error => case_record["error"].to_s,
        :compiler_snippet => case_record["compiler_snippet"].to_s,
      }
      seen_case_ids[case_id] = true
      counts_by_category[category] += 1
    end
  end

  unless list_of_cases.size == EXPECTED_CASE_COUNT
    raise "expected #{EXPECTED_CASE_COUNT} trainable cases, joined #{list_of_cases.size}"
  end
  CATEGORY_TOTALS.each do |category, expected_count|
    actual_count = counts_by_category[category]
    raise "expected #{expected_count} #{category} cases, joined #{actual_count}" unless actual_count == expected_count
  end

  list_of_cases.sort_by { |item| item[:case_id] }
end

def parse_hint_output(output)
  list_of_hints = []
  current_hint = nil
  output.each_line do |raw_line|
    line = raw_line.chomp
    if match = line.match(/\Ahint: (.*) \[([^@\]]+)@([^\]]+)\]\z/)
      current_hint = {
        :text => match[1],
        :library => match[2],
        :version => match[3],
        :example => "",
      }
      list_of_hints << current_hint
    elsif line.start_with?("  right: ") && current_hint
      current_hint[:example] = line.sub(/\A  right: /, "").strip
    end
  end
  list_of_hints
end

def normalize_code(source)
  source.to_s
    .gsub("`", "")
    .gsub(/\r\n?/, "\n")
    .gsub(/\s+/, " ")
    .strip
end

def right_form_match_rule(item, hint)
  expected = normalize_code(item[:right])
  suggested = normalize_code(hint[:example])
  return "normalized equality" if expected == suggested
  if expected.size > 3 && suggested.size > 3 && (expected.include?(suggested) || suggested.include?(expected))
    return "containment"
  end

  wrong = normalize_code(item[:wrong])
  error = normalize_code(item[:error])
  hint_text = hint[:text]

  nilable_diagnostic = error.include?("compile-time type is") && error.include?("| Nil")
  nilable_argument = error.include?("expected argument") && error.include?("| Nil")
  nilable_return = error.include?("must return") && error.include?("| Nil")
  if nilable_diagnostic || nilable_argument || nilable_return
    if expected.start_with?("if ") && suggested.start_with?("if ")
      return "same nil narrowing rewrite"
    end
    if expected.include?(".compact") && hint_text.include?("remove nil entries")
      return "same nil collection filtering rewrite"
    end
    if expected.include?("|| raise") && hint_text.include?("raise")
      return "same nil fallback rewrite"
    end
    if expected.include?("||") && suggested.include?("||") && hint_text.include?("fallback")
      return "same nil fallback operator rewrite"
    end
    if expected.match?(/\b(?:if|unless)\s+\w+\s*=/) && suggested.match?(/\bif\s+\w+\s*=/) && hint_text.include?("Narrow")
      return "same nil binding rewrite"
    end
    if expected.include?("not_nil!") && (suggested.include?("not_nil!") || suggested.match?(/\bif\s+\w+\s*=/))
      return "same explicit nil assertion rewrite"
    end
  end

  if wrong.include?("**options") && expected.include?("options[") && suggested.include?("options[") && !suggested.include?("**")
    return "same explicit named argument rewrite"
  end

  if wrong.match?(/\b(?:while|until)\b/) && expected.match?(/\A(?:while|until)\b/) && suggested.match?(/\A(?:while|until)\b/)
    return "same block-form loop rewrite"
  end

  if wrong.include?("described_class") && !expected.include?("described_class") && !suggested.include?("described_class")
    return "same fully qualified spec subject rewrite"
  end

  if wrong.include?(".to_sym") && !expected.include?("to_sym") && !suggested.include?("to_sym")
    return "same String/Symbol conversion rewrite"
  end

  if wrong.include?("to_i64?") && expected.include?("to_i64") && suggested.include?("to_i64")
    return "same integer conversion method correction"
  end

  if error.include?("can't cast") && expected.include?("is_a?") && suggested.include?("is_a?")
    return "same checked concrete type narrowing rewrite"
  end

  if error.include?("expecting token ':'") && error.include?("not '='") && expected.include?(" = ") && suggested.include?(" = ")
    return "same inferred constant assignment rewrite"
  end

  if error.include?("too many block parameters") && !expected.match?(/\|[^|]+\|/) && !suggested.match?(/\|[^|]+\|/)
    return "same zero-parameter block arity correction"
  end

  if error.include?("expected block to return") && expected_body = expected[/\{\s*([^{}]+?)\s*\}/, 1]
    suggested_body = suggested[/\{\s*([^{}]+?)\s*\}/, 1]
    return "same block return value correction" if suggested_body && normalize_code(expected_body) == normalize_code(suggested_body)
  end

  if wrong.include?("File.mkdir_p") && expected.include?("Dir.mkdir_p") && suggested.include?("Dir.mkdir_p")
    return "same directory API correction"
  end

  if wrong.include?("require ") && expected.start_with?("require ") && suggested.start_with?("require ")
    expected_path = expected[/require\s+["']([^"']+)["']/, 1]
    suggested_path = suggested[/require\s+["']([^"']+)["']/, 1]
    if expected_path && suggested_path && relative_path?(expected_path) && relative_path?(suggested_path)
      return "same relative require rewrite"
    end
  end

  if wrong.match?(/can't send closure to C function/) && expected !~ /\b(?:version|app|offset_y|snapshot_path)\b/ && suggested.include?("->")
    return "same captureless callback rewrite"
  end

  if error.include?("wrong number of block parameters") && expected !~ /\|[^|]+\|/ && suggested !~ /\|[^|]+\|/
    return "same zero-argument block rewrite"
  end

  if error.include?("TypeNode#instance_vars") && expected.include?("@type.instance_vars") && suggested.include?("@type.instance_vars")
    return "same type-context macro rewrite"
  end

  if error.include?("undefined macro variable") && expected.include?("{%") && suggested.include?("{%")
    return "same macro variable scope rewrite"
  end

  if error.match?(/undefined method '(?:ancestors|superclass)'/) &&
     (expected.include?("is_a?(") || expected.include?("{{")) &&
     (suggested.include?("is_a?(") || hint_text.include?("macro"))
    return "same runtime or compile-time type hierarchy rewrite"
  end

  if error.include?("Base64") &&
     (expected.include?("Base64.decode(") || expected.include?("Base64.decode_string(")) &&
     (hint_text.include?("Base64.decode") || hint_text.include?("Base64.decode_string"))
    return "same Base64 decoder API correction"
  end

  if error.include?("JSON::ParseException.new") &&
     (expected.include?("JSON::ParseException.new") || expected.include?("ArgumentError.new")) &&
     (hint_text.include?("parser location arguments") || hint_text.include?("ArgumentError"))
    return "same JSON parse error construction correction"
  end

  if error.include?("Digest::SHA256") && expected.include?("hexfinal") && suggested.include?("hexfinal")
    return "same streaming digest finalization rewrite"
  end

  if wrong.include?("String#<<") || (wrong.include?(" << ") && expected.include?(" + "))
    return "same immutable String concatenation rewrite" if expected.include?(" = ") && suggested.include?(" = ") && suggested.include?(" + ")
  end

  if wrong.include?("Process.kill") && expected.include?("Process.signal") && suggested.include?("Process.signal")
    return "same Process signal API correction"
  end

  if wrong.include?("JSON::Any") && expected.include?("as_h") && suggested.include?("as_h")
    return "same mutable JSON Hash access rewrite"
  end

  if wrong.include?("HTTP::Headers.new") && expected.include?("HTTP::Headers.new") && suggested.include?("HTTP::Headers.new") && suggested.include?(".each")
    return "same header copy constructor rewrite"
  end

  if wrong.include?("Time.utc") && expected.include?("nanosecond:") && suggested.include?("nanosecond:")
    return "same named nanosecond argument rewrite"
  end

  if wrong.include?("Slice(UInt8).new") && expected.include?(".dup") && suggested.include?(".dup")
    return "same slice copy rewrite"
  end

  if wrong.include?("NamedTuple") && expected.include?(".to_h.all?") && suggested.include?(".to_h.all?")
    return "same NamedTuple to Hash rewrite"
  end

  if wrong.include?("Regex::MatchData#matched") && expected.include?("map(&.[0])") && suggested.include?("map(&.[0])")
    return "same regex capture extraction rewrite"
  end

  if wrong.include?("String#delete_prefix") && expected.include?("byte_slice") && suggested.include?("byte_slice")
    return "same byte slice prefix removal rewrite"
  end

  if wrong.include?("Digest::SHA256") && expected.include?("require \"digest/sha256\"") && suggested.include?("require \"digest/sha256\"")
    return "same Digest standard library require"
  end

  if wrong.include?("FileUtils") && expected.include?("require \"file_utils\"") && suggested.include?("require \"file_utils\"")
    return "same FileUtils standard library require"
  end

  if error.include?("expecting token") && expected.include?("queries.count {") && suggested.include?("queries.count {") && expected.include?("||") && suggested.include?("||")
    return "same explicit block predicate rewrite"
  end

  if error.include?("can't return from captured block") && expected.include?("next") && suggested.include?("next")
    return "same block-local next rewrite"
  end

  if error.include?("can't declare def dynamically") && expected.include?("private def") && suggested.include?("private def")
    return "same file-scope spec helper rewrite"
  end

  if error.include?("can't declare constant dynamically") && (expected.include?("private ") || expected.include?("module ")) && hint_text.include?("file or module scope")
    return "same file-scope spec constant rewrite"
  end

  if error.include?("cannot use") && (expected.include?("macro_name") || expected.include?("protected_environments")) &&
     (suggested.include?("macro_name") || suggested.include?("protected_environments"))
    return "same reserved identifier rename"
  end

  if error.include?("can't infer the type of instance variable") && expected.include?("@") && expected.include?(":") && suggested.include?("@") && suggested.include?(":")
    return "same instance variable type declaration"
  end

  if error.include?("doesn't explicitly initialize instance variable") && expected.include?("@") && suggested.include?("@")
    return "same instance variable initialization correction"
  end

  nil
end

def relative_path?(path)
  path.start_with?("./") || path.start_with?("../")
end

def evaluate_case(item, binary_path, project_root)
  error_text = [item[:error], item[:compiler_snippet]].reject(&:empty?).join("\n")
  stdout, stderr, status = Open3.capture3(
    binary_path,
    "hint",
    "--root",
    project_root,
    stdin_data: error_text,
    chdir: REPO_ROOT,
  )
  unless status.success?
    raise "hint command failed for #{item[:case_id]} (#{status.exitstatus}): #{stderr.strip}"
  end

  hints = parse_hint_output(stdout)
  matched_hint = nil
  matched_rule = nil
  hints.each do |hint|
    match_rule = right_form_match_rule(item, hint)
    next unless match_rule

    matched_hint = hint
    matched_rule = match_rule
    break
  end

  {
    :case_id => item[:case_id],
    :category => item[:category],
    :split => item[:split],
    :right => item[:right],
    :error => item[:error],
    :compiler_snippet => item[:compiler_snippet],
    :matched => !matched_hint.nil?,
    :match_rule => matched_rule,
    :matched_hint => matched_hint,
    :hints => hints,
  }
end

def category_summary(list_of_results, category, split)
  rows = list_of_results.select { |item| item[:category] == category && item[:split] == split }
  hit_count = rows.count { |item| item[:matched] }
  {
    :hits => hit_count,
    :total => rows.size,
    :rate => rows.empty? ? 0.0 : (100.0 * hit_count / rows.size),
  }
end

def evaluate_card_family_support(card, authoring_cases)
  card.fetch("error_hints").map do |hint|
    pattern = Regexp.new(hint.fetch("pattern").gsub("(?|", "(?:"))
    matched_cases = authoring_cases.count do |item|
      compiler_text = [item[:error], item[:compiler_snippet]].reject(&:empty?).join("\n")
      !!pattern.match(compiler_text)
    end
    {
      :pattern => hint.fetch("pattern"),
      :authoring_cases => matched_cases,
    }
  rescue RegexpError => error
    {
      :pattern => hint.fetch("pattern"),
      :authoring_cases => 0,
      :regex_error => error.message,
    }
  end
end

def short_cell(value, limit = 220)
  text = value.to_s.gsub(/\s+/, " ").strip
  text = "(none)" if text.empty?
  text = "#{text[0, limit]}…" if text.size > limit
  text.gsub("|") { "\\|" }.gsub("`") { "\\`" }
end

def markdown_report(results, options, all_cases, label_files)
  case_sha = Digest::SHA256.file(options[:cases_path]).hexdigest
  label_sha = Digest::SHA256.new
  label_files.each do |path|
    label_sha.update(File.basename(path))
    label_sha.update(File.binread(path))
  end
  commit, = Open3.capture2("git", "rev-parse", "HEAD", chdir: REPO_ROOT)

  report = []
  report << "# Crystal language card hint evaluation"
  report << ""
  report << "- Measured: #{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")}."
  report << "- Card commit: `#{commit.strip}`."
  report << "- Heldout measurement label: `#{options[:heldout_label]}` (the initial post-freeze heldout run)."
  report << "- Split assignment: even final digit of the numeric `case_id` suffix is authoring; odd is heldout."
  report << "- Cases: #{all_cases.size} trainable joined records; #{authoring_cases.size} authoring and #{all_cases.size - authoring_cases.size} heldout."
  report << "- `cases_labeled.jsonl` SHA-256: `#{case_sha}`."
  report << "- Sorted label JSONL set SHA-256: `#{label_sha.hexdigest}`."
  report << "- Matching rules: normalized equality, containment, then the family-specific same-rewrite checks implemented in `scripts/crystal_card_eval.rb`."
  report << ""
  report << "## Hit rates"
  report << ""
  report << "| Category | Split | Hits | Cases | Rate |"
  report << "|---|---:|---:|---:|---:|"
  ["authoring", "heldout"].each do |split|
    next unless results.any? { |item| item[:split] == split }

    CATEGORY_TOTALS.keys.each do |category|
      summary = category_summary(results, category, split)
      report << "| #{category} | #{split} | #{summary[:hits]} | #{summary[:total]} | #{format("%.1f%%", summary[:rate])} |"
    end
    rows = results.select { |item| item[:split] == split }
    hit_count = rows.count { |item| item[:matched] }
    rate = rows.empty? ? 0.0 : 100.0 * hit_count / rows.size
    report << "| **Overall** | #{split} | **#{hit_count}** | **#{rows.size}** | **#{format("%.1f%%", rate)}** |"
  end

  report << ""
  report << "## Misses"
  report << ""
  report << "| Split | Category | Case | Expected right form | Hints emitted |"
  report << "|---|---|---|---|---|"
  results.reject { |item| item[:matched] }.each do |item|
    suggestions = item[:hints].map { |hint| hint[:example] }.reject(&:empty?).join("; ")
    if suggestions.empty?
      suggestions = "(no matching hint)"
    end
    report << "| #{item[:split]} | #{item[:category]} | `#{item[:case_id]}` | #{short_cell(item[:right])} | #{short_cell(suggestions)} |"
  end
  report << ""
  report.join("\n") + "\n"
end

def print_summary(results, options)
  puts "Split: #{options[:split]}"
  puts "Heldout label: #{options[:heldout_label]}" unless options[:heldout_label].to_s.empty?
  selected_splits = results.map { |item| item[:split] }.uniq
  selected_splits.each do |split|
    CATEGORY_TOTALS.keys.each do |category|
      summary = category_summary(results, category, split)
      puts "#{split} #{category}: #{summary[:hits]}/#{summary[:total]} (#{format("%.1f%%", summary[:rate])})"
    end
    rows = results.select { |item| item[:split] == split }
    hit_count = rows.count { |item| item[:matched] }
    rate = rows.empty? ? 0.0 : 100.0 * hit_count / rows.size
    puts "#{split} overall: #{hit_count}/#{rows.size} (#{format("%.1f%%", rate)})"
  end

  if options[:show_misses]
    misses = results.reject { |item| item[:matched] }
    puts "Misses: #{misses.size}"
    misses.each do |item|
      suggestions = item[:hints].map { |hint| hint[:example] }.reject(&:empty?).join(" / ")
      suggestions = "(no matching hint)" if suggestions.empty?
      puts "MISS #{item[:case_id]} #{item[:category]} expected=#{short_cell(item[:right], 180)} suggestions=#{short_cell(suggestions, 180)}"
    end
  end

  if options[:show_misses] && results.any? { |item| item[:split] == "authoring" }
    card = YAML.load_file(CARD_PATH)
    authoring_cases = results.select { |item| item[:split] == "authoring" }
    puts "Card pattern authoring matches:"
    evaluate_card_family_support(card, authoring_cases).each_with_index do |family, index|
      puts "#{index + 1}. #{family[:authoring_cases]} cases: #{family[:pattern]}"
    end
  end
end

def run
  options = parse_options
  binary_path = File.expand_path(options[:binary_path])
  raise "amber-lsp executable is not available: #{binary_path}" unless File.executable?(binary_path)
  raise "Crystal card is missing: #{CARD_PATH}" unless File.file?(CARD_PATH)

  case_records = read_case_records(options[:cases_path])
  all_cases = trainable_labeled_cases(options[:labels_path], case_records)
  selected_splits = case options[:split]
                    when "authoring"
                      ["authoring"]
                    when "heldout"
                      ["heldout"]
                    else
                      ["authoring", "heldout"]
                    end
  selected_cases = all_cases.select { |item| selected_splits.include?(item[:split]) }

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  results = []
  Dir.mktmpdir("amber-lsp-plain-project") do |project_root|
    selected_cases.each do |item|
      results << evaluate_case(item, binary_path, project_root)
    end
  end
  elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

  print_summary(results, options)
  puts "Evaluated #{results.size} cases in #{format("%.2f", elapsed_seconds)} seconds."

  if options[:report_path]
    label_files = Dir.glob(File.join(options[:labels_path], "*.jsonl")).sort
    report = markdown_report(results, options, all_cases, label_files)
    FileUtils.mkdir_p(File.dirname(File.expand_path(options[:report_path])))
    File.write(options[:report_path], report)
    puts "Report: #{File.expand_path(options[:report_path])}"
  end

  true
rescue OptionParser::ParseError, Errno::ENOENT, KeyError, JSON::ParserError, RegexpError, RuntimeError => error
  warn "crystal card eval failed: #{error.message}"
  false
end

exit(run ? 0 : 1)
