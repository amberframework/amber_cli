# Amber CLI 2.0.4

Amber CLI 2.0.4 makes persistence part of the supported Amber V2 web-app path.
A new application includes Grant ORM, SQLite, typed database settings, and
Micrate-powered database commands by default.

## Start a database-backed app

```bash
amber new pet_tracker --type web
cd pet_tracker
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
amber watch
```

Open <http://127.0.0.1:3000/pets/new>. The generated resource includes a Grant
model, request schema, HTML CRUD controller, ECR views, specs, resource route,
and reversible SQL migration. SQLite keeps the first run self-contained; pass
`-d pg` or `-d mysql` to `amber new` for a server database.

## What changed

- Added Grant and the selected database driver to every generated web app.
- Made SQLite the default database and connected development, test, and
  production settings through `config/database.cr`.
- Embedded Micrate in `amber database` for migrations, status, rollback, redo,
  reset, and seeding.
- Promoted model, scaffold, and migration generation to the supported beta path.
- Corrected scaffold forms, optional fields, resource routes, and form-body
  handling so generated create and update requests persist successfully.
- Added a release smoke test that generates a Pet resource, migrates both test
  and development databases, runs its specs, boots the app, creates a Pet, and
  updates it through the generated HTML forms.
- Added a native Linux ARM64 release artifact and a Windows x86-64 generated-app
  compile gate.

Amber V2 native applications, generated authentication, and generated APIs
remain preview surfaces in this release.
