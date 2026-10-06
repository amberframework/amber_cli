# API cards

Libraries can publish versioned lookup guidance in `.amber-lsp/api/*.yml`.
Each card declares `card_version`, `library`, and `applies_to`; optional fields
include `docs_flags`, `docs_entries`, `notes`, and `error_hints`.

An `error_hints` item contains a regular expression, hint text, and a right-form
example. The hint and example can interpolate captured text with `{1}`, `{2}`,
or a named placeholder such as `{method}`. Numbered placeholders use the
corresponding regular-expression capture group, starting at 1. Named
placeholders use named groups such as `(?<method>[a-z_]+)`. A placeholder with
no matching capture remains unchanged.

```yaml
error_hints:
  - pattern: "undefined method '([a-z_]+)' for ([A-Za-z_:]+)"
    hint: "Call {1} on {2}."
    example: "{2}.{1}()"
  - pattern: "undefined method '(?<method>[a-z_]+)' for Example::Widget"
    hint: "Try {method} on the widget."
    example: "Example::Widget.{method}()"
```

The `amber-lsp hint` command prints matching hints with the card's resolved
library version.
