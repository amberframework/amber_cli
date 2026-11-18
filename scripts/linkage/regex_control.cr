# Control program for scripts/check_generated_app_linkage.sh. It uses Regex,
# so its binary must show PCRE2; that proves the linkage check can fail.
pattern = Regex.new("a+b")
exit(pattern.matches?(ARGV[0]? || "aab") ? 0 : 1)
