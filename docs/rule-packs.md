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
