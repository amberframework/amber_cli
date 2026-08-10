# Amber V2 Beta Web App

This guide is the consumer smoke test for Amber CLI `2.0.2` and Amber
`2.0.0-beta.2`. It is expected to pass on Apple Silicon macOS and x86_64 Linux.

## 1. Verify the toolchain

```bash
crystal --version
shards --version
amber --version
```

Crystal must be at least 1.20 and earlier than 2.0. Amber CLI must be 2.0.2 or
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
grep 'template:' .amber.yml
```

The dependency must be `amberframework/amber` version `2.0.0-beta.2`; the
template must be `ecr`. A newly generated app must not contain a personal fork,
Grant, Gemma, Slang, or all three database drivers.

The first page carries a compact version of Amber's V2 visual language: warm
paper colors, a CSS faceted-crystal mark, editorial heading scale, status chips,
and a responsive first-edits panel. It should begin with “Your new idea starts
here” and list the page, route, and controller entry points. The starter uses no
remote font, image, JavaScript package, or front-end build step.

## 3. Test and build

```bash
crystal spec
crystal build src/amber_beta_smoke.cr -o bin/amber_beta_smoke
```

No running database is required for this core application.

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

## 5. Try core generators

```bash
amber generate controller Posts index show
amber generate schema Post title:string:required body:text
amber generate job PublishPost --queue=default
amber generate mailer Digest --actions=weekly
amber generate channel Updates --topics=posts
amber generate migration CreatePosts
```

Review generated files before adding them to an application. Run `crystal tool
format --check` and `crystal spec` after generation. These six core generator
paths run in the release smoke test on both supported platforms. See
[Generator support](GENERATOR_SUPPORT.md) for dependency-backed preview types.
