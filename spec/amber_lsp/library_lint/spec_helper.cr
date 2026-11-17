require "../spec_helper"

def write_library_lint_fixture_files(root_path : String, list_of_file_contents : Hash(String, String)) : Nil
  list_of_file_contents.each do |relative_path, source_code|
    absolute_path = File.join(root_path, relative_path)
    Dir.mkdir_p(File.dirname(absolute_path))
    File.write(absolute_path, source_code)
  end
end

def run_library_lint_git_command(root_path : String, list_of_arguments : Array(String)) : Nil
  output = IO::Memory.new
  error_output = IO::Memory.new
  status = Process.run("git", list_of_arguments, chdir: root_path, output: output, error: error_output)
  return if status.success?

  raise Exception.new("git #{list_of_arguments.join(" ")} failed: #{error_output}")
end

def run_library_lint_with_git_changes(
  list_of_base_files : Hash(String, String),
  list_of_changed_files : Hash(String, String),
  list_of_extra_arguments : Array(String) = [] of String,
  config_source : String? = nil,
) : Tuple(Int32, String, String)
  result : Tuple(Int32, String, String) = {0, "", ""}
  with_tempdir do |root_path|
    write_library_lint_fixture_files(root_path, list_of_base_files)
    if configuration_source = config_source
      File.write(File.join(root_path, ".amber-lsp.yml"), configuration_source)
    end

    run_library_lint_git_command(root_path, ["init", "-q"])
    run_library_lint_git_command(root_path, ["config", "user.name", "Spec Runner"])
    run_library_lint_git_command(root_path, ["config", "user.email", "spec@example.invalid"])
    run_library_lint_git_command(root_path, ["add", "-A"])
    run_library_lint_git_command(root_path, ["commit", "-m", "base fixture"])

    write_library_lint_fixture_files(root_path, list_of_changed_files)
    list_of_arguments = ["--since", "HEAD", "--root", root_path]
    list_of_arguments.concat(list_of_extra_arguments)
    output = IO::Memory.new
    error_output = IO::Memory.new
    exit_code = AmberLSP::LibraryLint::RunLibraryLintCheck.new(
      list_of_arguments,
      output,
      error_output,
    ).perform
    result = {exit_code, output.to_s, error_output.to_s}
  end
  result
end

def run_library_lint_for_files(
  list_of_file_contents : Hash(String, String),
  list_of_arguments : Array(String),
  config_source : String? = nil,
) : Tuple(Int32, String, String)
  result : Tuple(Int32, String, String) = {0, "", ""}
  with_tempdir do |root_path|
    write_library_lint_fixture_files(root_path, list_of_file_contents)
    if configuration_source = config_source
      File.write(File.join(root_path, ".amber-lsp.yml"), configuration_source)
    end

    arguments = list_of_arguments.dup
    arguments << "--root"
    arguments << root_path
    output = IO::Memory.new
    error_output = IO::Memory.new
    exit_code = AmberLSP::LibraryLint::RunLibraryLintCheck.new(arguments, output, error_output).perform
    result = {exit_code, output.to_s, error_output.to_s}
  end
  result
end
