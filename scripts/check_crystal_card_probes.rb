#!/usr/bin/env ruby

require "open3"
require "tmpdir"
require "yaml"

REPO_ROOT = File.expand_path("..", __dir__)
CARD_PATH = File.join(REPO_ROOT, "src", "amber_lsp", "cards", "crystal.yml")
PROBE_ROOT = File.join(REPO_ROOT, "spec", "fixtures", "crystal_card_probes")
PROBE_FILES = [
  "01_nil_narrowing.cr",
  "02a_nil_argument_narrowing.cr",
  "02_instance_variable_type.cr",
  "03_spec_scope.cr",
  "04_reserved_identifier.cr",
  "05_trailing_loop.cr",
  "06_named_arguments.cr",
  "07_json_require.cr",
  "08_uuid_yaml_require.cr",
  "09_relative_require.cr",
  "10_captureless_callback.cr",
  "11_block_arity.cr",
  "12_macro_type_scope.cr",
  "13_macro_variable_scope.cr",
  "14_string_to_sym.cr",
  "15_runtime_class_ancestry.cr",
  "16_base64.cr",
  "17_json_parse_exception.cr",
  "18_digest_api.cr",
  "21_integer_conversion.cr",
  "22_string_concatenation.cr",
  "23_process_signal.cr",
  "24_json_any_hash.cr",
  "25_json_builder_array.cr",
  "26_http_headers_copy.cr",
  "27_time_nanosecond.cr",
  "28_slice_copy.cr",
  "29_named_tuple_hash.cr",
  "30_regex_match_capture.cr",
  "31_string_byte_slice.cr",
  "32_digest_require.cr",
  "33_file_utils_require.cr",
  "34_block_predicate.cr",
  "35_block_next.cr",
  "19_directory_creation.cr",
  "20_spec_subject.cr",
  "36_nil_return.cr",
  "37_checked_cast.cr",
  "38_constant_assignment.cr",
  "39_block_arity.cr",
  "40_block_return.cr",
].freeze

def normalize_code(source)
  source.gsub(/;/, " ").gsub(/\s+/, " ").strip
end

def compile_card_probes
  card = YAML.load_file(CARD_PATH)
  hints = card.fetch("error_hints")
  raise "#{hints.size} card hints do not match #{PROBE_FILES.size} probe fixtures" unless hints.size == PROBE_FILES.size

  failures = []
  Dir.mktmpdir("amber-lsp-crystal-card-cache") do |cache_root|
    hints.zip(PROBE_FILES).each do |hint, probe_file|
      probe_path = File.join(PROBE_ROOT, probe_file)
      source = File.read(probe_path)
      example = hint.fetch("example")
      unless normalize_code(source).include?(normalize_code(example))
        failures << "#{probe_file}: card example is not present in the probe source"
        next
      end

      stdout, stderr, status = Open3.capture3(
        {"CRYSTAL_CACHE_DIR" => cache_root},
        "crystal-alpha",
        "build",
        "--no-codegen",
        probe_path,
        chdir: REPO_ROOT,
      )
      next if status.success? && stdout.empty? && stderr.empty?

      failures << "#{probe_file}: #{(stderr + stdout).strip}"
    end
  end

  if failures.empty?
    puts "GREEN: #{PROBE_FILES.size}/#{PROBE_FILES.size} Crystal card examples compiled with zero warnings."
    return true
  end

  failures.each { |failure| warn failure }
  warn "RED: #{PROBE_FILES.size - failures.size}/#{PROBE_FILES.size} Crystal card probes passed."
  false
end

exit(compile_card_probes ? 0 : 1)
