# Generator Support for the Amber V2 Beta

The support label describes whether output can be evaluated in the core web app
without adding an unreleased ecosystem dependency.

| Command | Beta status | Notes |
|---|---|---|
| `generate controller` | Supported | Controller, ECR action views, and specs |
| `generate schema` | Supported | Uses Amber's built-in Schema API |
| `generate job` | Supported | Uses Amber's built-in job system |
| `generate mailer` | Supported | Uses Amber's built-in mailer API |
| `generate channel` | Supported | Uses Amber WebSockets |
| `generate migration` | Supported output | Produces SQL migration files; applying them requires database tooling |
| `generate model` | Preview | Currently emits Grant-based output; Grant is not in the core app |
| `generate scaffold` | Preview | Includes Grant persistence and resource output |
| `generate api` | Preview | Includes a persistence-backed model |
| `generate auth` | Preview | Requires a compatible persistence/auth stack |
| `new --type native` | Preview | Has a separate multi-platform dependency and validation matrix |

Preview does not mean removed. It means the CLI may generate the files, but the
Amber beta release does not promise that a clean web application will compile
them without additional work. The CLI prints a warning before generating a
dependency-backed preview surface.

Amber V2 supports ECR only. The CLI ignores legacy Slang settings for new
output; migrate old `.slang` files before using V2 generators.
