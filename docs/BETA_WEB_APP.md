# Amber V2 Beta Web App

This guide is the consumer smoke test for Amber CLI `2.0.4` and Amber
`2.0.0-beta.3`. It is expected to pass on Apple Silicon macOS, x86_64 Linux,
and ARM64 Linux. Windows x86-64 compilation is checked in CI.

## 1. Verify the toolchain

```bash
crystal --version
shards --version
amber --version
```

Crystal must be at least 1.20 and earlier than 2.0. Amber CLI must be 2.0.4 or
newer.

## 2. Generate the web app

```bash
amber new amber_beta_smoke --type web
cd amber_beta_smoke
```

The command installs dependencies unless `--no-deps` is passed. Inspect the
contract before continuing:

```bash
grep -A2 'amber:' shard.yml
grep -E '^(template|database|model):' .amber.yml
```

The dependency must be `amberframework/amber` version `2.0.0-beta.3`; the
template must be `ecr`, the database must be `sqlite`, and the model layer must
be `grant`. `shard.yml` must include Grant and `crystal-sqlite3`, but it must not
include Gemma, Slang, PostgreSQL, or MySQL unless you selected that database.

The first page carries a compact version of Amber's V2 visual language: warm
paper colors, a CSS faceted-crystal mark, editorial heading scale, status chips,
and a responsive first-edits panel. It should begin with “Your new idea starts
here” and list the page, route, and controller entry points. Its local
JavaScript entry point is resolved through a browser-native import map. The
starter uses no remote font, image, JavaScript package, or front-end build step.

## 3. Test and build

```bash
crystal spec
crystal build src/amber_beta_smoke.cr -o bin/amber_beta_smoke
```

No database server is required: the default development and test databases are
local SQLite files under `db/`.

## 4. Start and probe it

```bash
amber watch
```

From another terminal:

```bash
curl --fail http://127.0.0.1:3000/
curl --fail http://127.0.0.1:3000/css/app.css
```

The first request validates routing, the controller, and ECR rendering. The
second validates the static pipeline. Confirm the deployed scaffold, rather
than an older cached template, with:

```bash
curl --fail http://127.0.0.1:3000/ | grep 'Your new idea'
curl --fail http://127.0.0.1:3000/css/app.css | grep -- '--amber-accent: #e96918'
```

## 5. Generate and migrate a real resource

```bash
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
AMBER_ENV=test amber database migrate
amber database status
crystal spec
```

That one scaffold command creates:

- `src/models/pet.cr` — the Grant model
- `src/schemas/pet_schema.cr` — typed request validation
- `src/controllers/pet_controller.cr` — HTML CRUD actions
- `src/views/pet/*.ecr` — index, show, new, edit, and shared form views
- `db/migrations/*_create_pets.sql` — Micrate Up/Down SQL
- `spec/models/pet_spec.cr` and `spec/controllers/pet_controller_spec.cr`
- `resources "/pets", PetController` inside `config/routes.cr`

Restart `amber watch`, open <http://127.0.0.1:3000/pets/new>, and create a
record. The create form posts to `/pets`; the edit form sends `_method=PATCH`
to `/pets/:id`.

## 6. Try the other supported generators

```bash
amber generate controller Posts index show
amber generate schema Post title:string:required body:text
amber generate model Person name:string:required
amber generate job PublishPost --queue=default
amber generate mailer Digest --actions=weekly
amber generate channel Updates --topics=posts
amber generate migration CreatePosts
```

Review generated files before adding them to an application. Run
`amber database migrate`, `crystal tool format --check src spec`, and
`crystal spec` after generation. The release smoke test generates, migrates,
compiles, and exercises a Pet create/update flow. See
[Generator support](GENERATOR_SUPPORT.md) for the remaining preview surfaces.
