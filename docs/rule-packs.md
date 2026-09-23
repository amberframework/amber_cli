# Library rule packs

Library rule packs let a Crystal library ship opt-in feature guidance and edit-time checks with the same `.claude/` files that Shards distributes. `amber-lsp` reads packs from installed dependencies at `lib/*/.claude/rules/*.yml` and from the project at `.claude/rules/*.yml`; no copy step is required. A project pack with the same `pack` id overrides a dependency pack. A pack whose `library` equals the project's own shard name does not apply, because that pack describes the library's consumer contract.

## Pack document

Each YAML file has a pack identity, declared modes, optional evidence patterns, mode-specific context, and rules:

```yaml
pack: grant/tenancy
library: grant
version: 1.0.0

modes:
  row:
    declared_by:
      key_path: grant.tenancy
      expected_value: row
    evidence:
      - '^\s*multitenant\b'
    tenant_column: tenant_id
    context: |
      Scope queries with the library's tenant context.
  schema:
    declared_by:
      key_path: grant.tenancy
      expected_value: schema
    evidence:
      - '^\s*SchemaTenant\.with\b'
    context: |
      Schema-specific rules are not included yet.

rules:
  - id: grant/example
    modes: [row]
    severity: warning
    applies_to: ["src/**"]
    exclude_from: ["src/controllers/**"]
    message: "Explain the finding and the repair."
    check:
      kind: line_regex
      pattern: '\bunsafe_call\b'
```

`declared_by.key_path` is a dotted path into the application's `shard.yml`; `expected_value` is compared as a string. A pack rule runs only when one of its modes is declared. Evidence patterns scan the application's `.cr` files outside `lib/`, `.git/`, `tmp/`, and `vendor/`; they support mixed-mode detection and the undeclared-feature warning. Evidence alone does not activate mode-specific rules. Context blocks are printed only for declared modes and should stay to about 15 lines or fewer.

Each rule requires an id, one or more mode names, a severity, file globs, a message, and one check. Severity values are `error`, `warning`, `info`, and `hint`. `exclude_from` is optional. `applies_to` and `exclude_from` use Crystal path globs, including `**` for recursive directories. Rules can be enabled, disabled, or have their severity overridden through the existing `.amber-lsp.yml` `rules` mapping.

## Check kinds

### `line_regex`

Matches a regular expression on each line and uses the existing custom-rule diagnostic matcher. `negate: true` reports once at the start of a file when the pattern does not occur.

```yaml
check:
  kind: line_regex
  pattern: '^\s*[^#]*\.unscoped\b'
```

### `file_requires`

Reports on each line matching `trigger_pattern` when the file has no line matching `required_pattern`. If `trigger_pattern` is omitted, `amber-lsp` uses the first mode's `tenant_column` as a Crystal `column <name>` declaration.

```yaml
check:
  kind: file_requires
  required_pattern: '^\s*multitenant\b'
```

### `call_outside_block`

Uses `Crystal::Parser` and a `Crystal::Visitor` to inspect method calls. `source_globs` select the files where `tenant_macro` declarations identify scoped model names. `methods` lists calls on those model constants that can query the database. A dotted `required_call`, such as `Grant::Tenant.with`, permits calls lexically inside its block and nested blocks. `escape_call` permits calls only inside a block on that same model receiver, such as `Todo.unscoped { Todo.where(...) }`. A method definition starts a new lexical scope, so a query written in a method body does not become tenant-scoped just because the method definition appears inside a tenant block. Receiver constants are followed through chained calls, but model instances held in variables are not resolved. The current matcher uses the last constant name, so same-named models in different namespaces can be ambiguous.

```yaml
check:
  kind: call_outside_block
  source_globs: ["src/models/**"]
  tenant_macro: multitenant
  methods: [where, find, all, first, count]
  required_call: Grant::Tenant.with
  escape_call: unscoped
```

`required_call` may be omitted when `escape_call` alone defines the allowed block. The rule intentionally does not infer receiver types or follow aliases stored in local variables.

### `project_conflict`

Runs over project state rather than one source line. The default `condition: mixed_modes` reports when every listed mode is declared or has evidence. `condition: evidence_without_declaration` reports when a listed mode has feature evidence but its declaration is absent; use one mode for this warning.

```yaml
check:
  kind: project_conflict
  condition: mixed_modes
```

## Project activation and context

Amber's built-in convention rules remain gated on an `amber` dependency. Library packs run in any project when the pack applies, including a project with only a Grant dependency. Pack diagnostics use the ordinary LSP diagnostic channel and `.amber-lsp.yml` severity overrides.

Run `amber-lsp context [--root DIR]` to print the context blocks for declared pack modes and one warning line per pack whose feature is used without a declaration. It prints nothing when no pack is declared or evidenced. Exit status is 0 for successful context inspection; invalid command arguments or an unreadable project return nonzero.
