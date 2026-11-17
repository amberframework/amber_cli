# Library rule packs

Library rule packs let a Crystal library ship feature guidance and edit-time
checks for `amber-lsp`, a harness-neutral tool. The pack uses amber-lsp's YAML
format and lives in the library at `.amber-lsp/packs/<name>.yml`. The engine
discovers installed dependency packs at `lib/*/.amber-lsp/packs/*.yml` and
project packs at `.amber-lsp/packs/*.yml`. A project pack with the same `pack`
id overrides a dependency pack. A pack whose `library` equals the project's
own shard name does not apply, because that pack describes the library's
consumer contract.

## Pack document

Each YAML file has a pack identity, source-detected modes with context, and
rules:

```yaml
pack: grant/tenancy
library: grant
version: 2.0.0

modes:
  row:
    context: |
      Row tenancy was detected from the app's multitenant model macros.
  schema:
    context: |
      Schema tenancy was detected from the app's schema-tenant declarations.

rules:
  - id: grant/example
    modes: [row]
    severity: warning
    applies_to: ["src/**"]
    exclude_from: ["spec/**"]
    message: "Explain the finding and the repair."
    check:
      kind: crystal_ast
      operation: chained_unscoped_on_tenant_model
```

For Grant, `amber-lsp` parses Crystal source under the app's `src/` and
`config/` directories to detect tenancy. It does not scan installed `lib/` code
or `spec/` files for mode declarations. Row mode comes from each class body's
`multitenant :column` macro, and the engine captures that tenant column per
model. Schema mode comes from a `Grant::SchemaTenant.with(...)` call or a
`schema_tenant_excluded` macro in a class body. Comments and string contents do
not count as declarations, and an unparsable source file is skipped.

A mode named `always` is active in every project that has the shard installed.
Amber's own pack uses it. An older `amber-lsp` that does not know a mode skips it.

Rules run only when one of their listed modes is detected. Context blocks are
printed by `amber-lsp context [--root DIR]` for detected modes. There is no
shard.yml feature declaration or evidence-without-declaration warning. The
engine reads shard.yml only for package identity and installed dependency
names.

Each rule requires an id, one or more mode names, a severity, file globs, a
message, and one check. Severity values are `error`, `warning`, `info`, and
`hint`. `exclude_from` is optional. `applies_to` and `exclude_from` use Crystal
path globs, including `**` for recursive directories. Rules can be enabled,
disabled, or have their severity overridden through the existing
`.amber-lsp.yml` `rules` mapping.

## Check kinds

### `line_regex`

Matches a regular expression on each line using the existing custom-rule
diagnostic matcher. `negate: true` reports once at the start of a file when the
pattern does not occur.

```yaml
check:
  kind: line_regex
  pattern: '^\\s*[^#]*\\.unsafe_call\\b'
```

### `file_requires`

Reports on each line matching `trigger_pattern` when the file has no line
matching `required_pattern`. Both are explicit regular expressions.

```yaml
check:
  kind: file_requires
  trigger_pattern: '^\\s*column\\s+account_id\\b'
  required_pattern: '^\\s*multitenant\\b'
```

### `call_outside_block`

Uses `Crystal::Parser` and a `Crystal::Visitor` to inspect method calls.
`source_globs` select the files where `tenant_macro` declarations identify
scoped model names. `methods` lists calls on those model constants that can
query the database. A dotted `required_call`, such as `Grant::Tenant.with`,
permits calls lexically inside its block and nested blocks. `escape_call`
permits calls only inside a block on that same model receiver, such as
`Todo.unscoped { Todo.where(...) }`. A method definition starts a new lexical
scope. Receiver constants are followed through chained calls, but model
instances held in variables are not resolved.

```yaml
check:
  kind: call_outside_block
  source_globs: ["src/models/**"]
  tenant_macro: multitenant
  methods: [where, find, all]
  required_call: Grant::Tenant.with
  escape_call: unscoped
```

### `crystal_ast`

Runs one of the named AST operations used by Grant's tenancy pack. The parser
visitors inspect Crystal call, class, block, and literal nodes rather than
matching source lines. Supported operations are `chained_unscoped_in_request_code`,
`chained_unscoped_bulk_write`, `chained_unscoped_on_tenant_model`,
`unscoped_block_in_request_code`, `spawn_inside_tenant_block`,
`tenant_column_without_multitenant`, `raw_connection_sql_on_tenant_table`,
`tenant_clear_in_app_code`, and `schema_query_outside_tenant`.

```yaml
check:
  kind: crystal_ast
  operation: tenant_column_without_multitenant
```

### `project_conflict`

Runs over project state. The supported `condition: mixed_modes` reports when
both listed modes are detected in the app's Crystal source.

```yaml
check:
  kind: project_conflict
  condition: mixed_modes
```

## Project activation and context

Amber's built-in convention rules remain gated on an `amber` dependency.
Library packs run in any project when a pack mode is detected, including a
non-Amber app with Grant installed. Pack diagnostics use the ordinary LSP
diagnostic channel and `.amber-lsp.yml` severity overrides.

Run `amber-lsp context [--root DIR]` to print the context blocks for detected
pack modes. It prints nothing when no mode is detected. Exit status is 0 for
successful context inspection; invalid command arguments or an unreadable
project return nonzero.

## Library lint command

The command-only library rules run through `amber-lsp check`. They use a
separate list from `RuleRegistry`, so the editor keeps its existing diagnostic
set.

```text
amber-lsp check [--since REF] [--all] [--carried-in PATH]... [--format text|json|github] [--advisory] [--root DIR] [PATH...]
```

The default paths are `src` and `spec`; directories are scanned recursively
for `*.cr` files. `--root` selects the project root. `--since REF` compares the
working tree with `git merge-base REF HEAD` and keeps findings on added lines.
`--all` reports all file-level findings. Changed-method collars run with
`--since`, where the changed line overlaps the method body.

The command loads rule enablement and severity from `.amber-lsp.yml`. It accepts
the existing `rules` mapping and `exclude_patterns`. A carried-in path is
scanned even when an exclusion covers it; within that path, the command keeps
the four carry-in-safe rules: `library/swallowed-rescue`,
`library/unchecked-cast`, `library/unsynchronized-class-variable`, and
`library/disabled-certificate-verification`.

```yaml
rules:
  library/typed-raise:
    enabled: false
  library/vague-internal-name:
    severity: information
exclude_patterns:
  - src/generated/**/*.cr
```

Findings use the rule's configured severity. `warning` and `error` are
classified as blocking; `information` and `hint` are advisory. The `--advisory`
option returns exit status 0 while keeping every finding and its classification
in the output. Without it, blocking findings return 1. Successful checks return
0; invalid arguments and failed git commands return 2.

`--format text` prints `PATH:LINE:COLUMN [classification] rule: message` and
the final blocking/advisory counts. `--format json` prints a JSON object with
`issues` (`path`, `line`, `column`, `classification`, `rule`, and `message`),
`blocking_count`, and `advisory_count`. `--format github` prints one GitHub
warning annotation per finding followed by the same counts line.

### Rule list

| Rule | Reports | Default classification |
|---|---|---|
| `library/typed-raise` | Receiverless `raise` calls with string literals or interpolations. | Blocking |
| `library/environment-read` | Calls through the `ENV` path. | Blocking |
| `library/stdlib-reopen` | Top-level definitions reopening configured core types. | Blocking |
| `library/log-setup` | `Log.setup`, `Log.setup_from_env`, and global `Log` setup calls. | Blocking |
| `library/process-output` | Receiverless `puts`, `print`, `printf`, `p`, and `pp` calls. | Blocking |
| `library/swallowed-rescue` | Untyped or `Exception` rescue clauses that swallow failures or replace them without preserving the cause. | Blocking |
| `library/unchecked-cast` | `.as(T)` casts to named types. | Blocking |
| `library/unsynchronized-class-variable` | Collection-valued class variables in files without `Mutex` or `Atomic`. | Blocking |
| `library/disabled-certificate-verification` | Paths ending in `VerifyMode::NONE`. | Blocking |
| `library/public-return-type` | Documented public methods without explicit return types, with lifecycle and `:nodoc:` exemptions. | Blocking |
| `library/vague-internal-name` | Vague local names, block parameters, and private method parameters. | Advisory |
| `library/collared-spec` | Method behavior describes without a golden case and both boundary contexts. | Blocking |
| `library/public-method-has-spec` | Public methods with arguments and no matching `describe` selector. | Blocking |
| `library/spec-without-assertion` | `it` blocks without a recognized assertion call. | Blocking |
| `library/changed-method-collar` | Changed behavior methods whose public entry point lacks collared coverage. | Blocking |

### Collared specs and private callers

A method behavior describe has a direct golden `it` or ordinary `context`, a
context beginning `at the boundary`, and a context beginning
`just past the boundary` with an expected-failure assertion. The expected
failure calls include `expect_raises`, `should_not`, `be_nil`, `be_false`, and
`be_empty`. A valid `# collar: none, <reason>` comment immediately above the
describe or changed method records a deliberate exemption.

For changed private or protected methods, `library/changed-method-collar`
builds a call index from every `src/**/*.cr` file. Reopened types merge by
fully qualified name. A no-receiver or `self` call connects methods on the
same type. The rule walks private and protected callers until it reaches public
methods that belong to the documented public type. At least one reachable
public caller needs a matching collared describe. A public `initialize` uses
the `describe ".new"` selector. If no public caller exists in the type, the
finding names that condition and directs the collar to the nearest public entry
point.
