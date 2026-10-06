# AI assistant setup

Amber CLI adds project hooks for Claude Code and Codex. From the project root,
run:

```bash
amber setup:agent
amber doctor
```

`setup:agent` creates or refreshes the hook files and merges them with the
project's existing Claude and Codex settings. Review and commit the generated
files. `amber doctor` reports whether the hooks, trust settings, LSP binary,
and API lookup index are ready.

Install a checksum-verified `amber-lsp` binary and `crystal-alpha` to enable
Crystal edit checks. The pre-tool hook checks the edited Crystal file before
the agent writes it, and the post-edit hook formats and analyzes that file.
If setup is incomplete, run `amber setup:agent` again and follow the readiness
message.

Use API lookup and compiler hints from the project root:

```bash
amber-lsp lookup 'Dir.mkdir_p'
crystal-alpha build src/my_app.cr 2>&1 | amber-lsp hint
```

`lookup` searches the Amber and Crystal API index. `hint` reads compiler output
from standard input and prints a matching API card hint when one is available.
