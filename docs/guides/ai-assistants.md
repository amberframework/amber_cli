# Agent tooling for Crystal projects

Amber CLI ships two tools that help coding agents such as Claude Code and Codex
write Crystal that compiles the first time:

- **`amber-lsp`** answers API questions from your project's real code: its
  own source, every shard in `lib/`, and the Crystal standard library. It also
  runs as a language server for editors.
- **`amber setup:agent`** connects Claude Code and Codex to `amber-lsp` in one
  project. It installs hooks that tell the agent to look methods up before it
  calls them, and that hold back Crystal edits until the tooling is ready.

Both work in any Crystal project. You do not need an Amber app.

| Project | API lookup and compiler hints | Edit gate and formatting | Amber V2 rule checks |
|---|---|---|---|
| Amber V2 app | Yes | Yes | Yes, plus library rule packs |
| Plain Crystal app (`crystal init app`) | Yes | Yes | Not applicable |
| Crystal shard (`crystal init lib`) | Yes | Yes | Not applicable |

## Install

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli
amber --version
amber-lsp --version
```

Homebrew installs `amber`, `amber-lsp`, the checksum file that the hooks
verify `amber-lsp` against, the bundled Crystal API card, Crystal, and
Minecart. See the [README](../../README.md#install) for the tap trust step and
for direct release archives.

`amber-lsp` uses `crystal-alpha` when it is installed and stock `crystal`
otherwise.

## Set up a project

From the project root (the directory that holds `shard.yml`):

```bash
amber setup:agent
amber doctor
```

`amber new` runs `setup:agent` for you. Run it again after you upgrade Amber
CLI, because it refreshes the generated files. It merges with your existing
settings and instructions, so it is safe to repeat.

Then trust the project once in each agent:

- **Claude Code:** open the project and accept the workspace trust prompt.
  Project hooks and the bundled `amber-lsp` plugin load only in trusted
  folders.
- **Codex:** review and trust the project hooks in `.codex/hooks.json`. Codex
  skips project hooks it has not trusted.

`amber doctor` reports both trust states, and it ends with exit 0 when
everything is ready.

### Commit the generated files

Commit these so every clone and every `git worktree` gets the same setup:

| File | Purpose |
|---|---|
| `.amber/agent_setup.json` | The amber_cli version and the minimum `amber-lsp` version this setup expects |
| `.amber/amber-agent-hook` | The POSIX shell hook that Claude Code and Codex both call |
| `.amber/claude-marketplace/` | A project-local Claude plugin that registers `amber-lsp` as the Crystal language server |
| `.claude/settings.json` | Claude Code hooks, plus the plugin marketplace entry |
| `.codex/hooks.json` | Codex hooks |
| `CLAUDE.md`, `AGENTS.md` | An "Agent loop" block that tells the agent to look up library methods before calling them |

When `.gitignore` or `.git/info/exclude` hides `.claude` or `.codex`,
`setup:agent` warns you: agent worktrees would run without the hooks.

## What the agent experiences

| When | What happens |
|---|---|
| Session start | The agent reads whether setup is ready, the `amber-lsp` version, and the instruction to look up methods first. |
| Before a `.cr` edit | The edit is refused if `amber-lsp` is missing, older than the recorded minimum, or fails its checksum. The refusal tells the agent to ask you to run `amber setup:agent`. |
| After a `.cr` edit | The file is formatted. In an Amber V2 app it is also checked against the Amber rules, and findings go back to the agent. |
| When the agent stops | The project is built (`--no-codegen`, or through `crystal-alpha watch` when a watcher is running), and compiler errors go back to the agent. |

## Use amber-lsp yourself

Run these from the project root, or pass `--root DIR`.

```bash
amber-lsp lookup 'Dir.mkdir_p'           # a class method
amber-lsp lookup 'String#split'          # an instance method
amber-lsp lookup 'MyApp::Invoice'        # a type
amber-lsp lookup 'Array#map' --json     # JSON for scripts
crystal build src/my_app.cr 2>&1 | amber-lsp hint
amber-lsp --help
```

`lookup` prints the signature, the resolved return type, where the method is
defined, its doc comment, and any notes from API cards. In a script, read the
exit code: 0 found, 3 several candidates, 4 unknown, 5 absent, 2 failed.
`--verify` compiles a small probe when the index cannot answer, which confirms
whether the method exists and what it returns.

`hint` reads compiler output on stdin. When an error matches a known mistake
described in an API card, it prints the fix and an example.

The first lookup in a project builds a docs index for each layer (the project,
each shard, and the standard library) and caches it under
`~/.cache/amber-lsp/index`. Later lookups take milliseconds, and a layer is
rebuilt when its source changes.

## For library authors

A shard can ship notes and compiler-error hints for its own API in
`.amber-lsp/api/*.yml`. Every project that depends on the shard picks the card
up from `lib/`. See [API cards](../api-cards.md) for the format, and
[rule packs](../rule-packs.md) for edit-time checks a library can add, which
run in Amber V2 apps.

## Troubleshooting

Run `amber doctor`. Each failed item names its fix. The common ones:

| Doctor says | Do this |
|---|---|
| `amber-lsp` was not found | Install Amber CLI, or set `AMBER_LSP_BIN` to the binary. |
| The checksum is missing or does not match | Reinstall from Homebrew or a release archive; keep `amber-lsp.sha256` next to the binary or `checksums.txt` in `share/amber_cli/`. |
| Claude workspace trust is not accepted | Open the project in Claude Code and accept the trust prompt. |
| Codex project hooks are not all trusted | Trust `.codex/hooks.json` in Codex. |
| Hooks or instructions are out of date | Run `amber setup:agent`. |
