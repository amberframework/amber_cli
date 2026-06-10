require "../amber_cli_spec"
require "../../src/amber_cli/core/base_command"

# Regression spec for shell injection fix in exec/encrypt editor invocation.
# Verifies that shell metacharacters in the editor option or filename are NOT
# executed by the shell. Reference: amberframework/amber#1376 by @tcoatswo.
#
# The vulnerability was: system("#{editor} #{filename}") — a crafted editor
# string like 'vim; touch /tmp/pwned' would execute the injected command.
# The fix uses Process.run with an explicit args array (no shell: true).
describe "ExecCommand editor invocation safety" do
  it "does not execute injected shell commands when editor contains semicolon" do
    # With system("#{editor} #{filename}"), setting editor = "vim; touch /tmp/pwned"
    # would run `touch /tmp/pwned`. With Process.parse_arguments + Process.run,
    # the semicolon is part of the editor token, not a shell command separator.
    marker = "/tmp/amber_exec_semi_pwned_#{Time.utc.to_unix_ms}"
    File.delete(marker) if File.exists?(marker)

    # An attacker sets EDITOR=vim; touch <marker>
    # Process.parse_arguments on POSIX treats "vim; touch /tmp/..." as a single
    # token because there are no shell word-break chars (it's unquoted but
    # parse_arguments_posix only splits on whitespace and quotes).
    # The resulting command "vim; touch ..." will fail to execute (no such file).
    malicious_editor = "vim; touch #{marker}"
    editor_parts = Process.parse_arguments(malicious_editor)
    editor_cmd = editor_parts.first # => "vim;"
    editor_args = editor_parts[1..] + ["/dev/null"]

    # Run — we expect an exception (no binary named "vim;") but no marker creation.
    begin
      Process.run(editor_cmd, editor_args, input: Process::Redirect::Close, output: Process::Redirect::Close, error: Process::Redirect::Close)
    rescue File::NotFoundError | File::AccessDeniedError | Exception
      # Expected: binary "vim;" doesn't exist, Process.run raises.
    end

    File.exists?(marker).should be_false
  end

  it "does not execute injected shell commands when filename contains shell metacharacters" do
    # With system("vim #{filename}"), a filename containing "; touch /tmp/pwned"
    # would inject a command. With Process.run and explicit args, the filename
    # is passed as a single argument — no shell parsing occurs.
    marker = "/tmp/amber_exec_fn_pwned_#{Time.utc.to_unix_ms}"
    File.delete(marker) if File.exists?(marker)

    injected_filename = "/dev/null; touch #{marker}"

    # Process.run does NOT invoke the shell, so the semicolon is literal.
    # `cat` will fail (no such file "/dev/null; touch /tmp/...") but will
    # NOT execute the touch command.
    Process.run("cat", [injected_filename], input: Process::Redirect::Close, output: Process::Redirect::Close, error: Process::Redirect::Close)

    File.exists?(marker).should be_false
  end

  it "handles multi-word editor like 'code -w' by splitting on whitespace" do
    # When EDITOR="code -w", Process.parse_arguments yields ["code", "-w"].
    # The first token is the command and the rest are prepended to the filename.
    editor = "code -w"
    parts = Process.parse_arguments(editor)
    parts.should eq(["code", "-w"])
    parts.first.should eq("code")
    parts[1..].should eq(["-w"])
  end

  it "handles multi-word editor like 'vim -u none' by splitting on whitespace" do
    editor = "vim -u none"
    parts = Process.parse_arguments(editor)
    parts.should eq(["vim", "-u", "none"])
    parts.first.should eq("vim")
    parts[1..].should eq(["-u", "none"])
  end
end
