# Asset Pipeline Native Integration Handoff

Date: April 17, 2026

Audience: the next agent working in `amber_cli` and `amber`

## Why this handoff exists

`asset_pipeline` is now far enough along that it should be treated as the
native UI layer, not as the place where we keep building higher-level app
shell automation.

That boundary matters.

The correct split is:

- `asset_pipeline`: native UI primitives, renderer bridges, HIG validation,
  and export-oriented scaffold helpers for system-owned Apple surfaces
- `amber`: application framework, domain mapping, business logic composition,
  process managers, configuration, and runtime patterns
- `amber_cli`: project generation, host app scaffolding, target wiring,
  automation, and regeneration workflows

Do not push generator logic or app-shell orchestration back into
`asset_pipeline`. It has already done its job.

## Current state of asset_pipeline

The Apple-native track in `asset_pipeline` is effectively complete for this
phase:

- `61` implemented component or platform surfaces
- `49` auditable studies at `pass_with_notes`
- `0` pending or invalid evidence rows

Important shell/export surfaces already exist and should now be *consumed* by
Amber and Amber CLI rather than reimplemented there:

- `UI::Widgets#export_widgetkit_scaffold`
- `UI::LiveActivities#export_activitykit_scaffold`
- `UI::AppShortcuts#export_app_intents_scaffold`
- `UI::NotificationsCatalog#export_swift_scaffold`
- `UI::HomeScreenQuickActions.export_plist_fragment`

These are deliberately conservative exports. They model the metadata and emit
deterministic Swift starter code. Amber/Amber CLI should be the layer that
places those exports into real host projects and wires them into extension
targets.

## Relevant files in asset_pipeline

Use these as the source of truth for what is now available:

- `src/ui/widgets.cr`
- `src/ui/live_activities.cr`
- `src/ui/app_shortcuts.cr`
- `src/ui/notifications.cr`
- `src/ui/quick_actions.cr`
- `src/ui/menu_bar.cr`
- `src/ui/status_bar.cr`
- `src/ui/windows.cr`
- `docs/APPLE_NATIVE_UI_STATUS.md`

The validation dashboard is now exposed at:

- `asset_pipeline/docs/apple-native-validation/index.html`

## Current state of Amber CLI

Amber CLI already has a meaningful start on native app generation:

- `src/amber_cli/commands/new.cr` supports `amber new my_app --type native`
- `src/amber_cli/generators/native_app.cr` builds a native project scaffold
- `spec/generators/native_app_spec.cr` exercises that scaffold heavily
- `docs/NATIVE_APP_TESTING.md` documents native app testing structure

This is great groundwork, but it currently stops short of the most valuable
part:

1. generating extension-target-ready host scaffolds for Apple shell surfaces
2. giving the app developer an ergonomic way to declare which platform
   capabilities they want
3. regenerating those host files safely when the declaration changes

That is the next job.

## What Amber / Amber CLI should own next

### 1. App-level capability declaration

Amber needs a first-class declaration of app shell capabilities that sit
*above* `asset_pipeline`.

Examples:

- windows
- menu bar
- status bar items
- notifications
- App Shortcuts
- Home Screen Quick Actions
- widgets
- live activities
- watch companions / future platform branches

This should be an application-level configuration object or manifest, not a
random pile of generated files.

Suggested shape:

- a new app manifest file checked into the generated project
- or a structured native section inside `.amber.yml`

Example conceptual structure:

```yaml
native:
  apple:
    windows:
      main:
        title: "My App"
        default_size: [1200, 820]
    menu_bar:
      enabled: true
    notifications:
      enabled: true
      categories:
        - exports
    shortcuts:
      enabled: true
    quick_actions:
      enabled: true
    widgets:
      enabled: true
    live_activities:
      enabled: true
```

The manifest should describe *intent*, not low-level Xcode details.

### 2. Generator output for host targets

Amber CLI should generate host-project artifacts that consume the export
surfaces from `asset_pipeline`.

For Apple platforms, this means generating:

- app-host Swift files
- extension target Swift files
- target-specific plist fragments
- XcodeGen/YAML definitions
- build scripts
- wiring code that pulls exported scaffold text from Crystal and places it into
  stable files

Concrete examples:

- WidgetKit extension target files from `UI::Widgets#export_widgetkit_scaffold`
- ActivityKit extension target files from
  `UI::LiveActivities#export_activitykit_scaffold`
- AppIntents provider files from
  `UI::AppShortcuts#export_app_intents_scaffold`
- notification category registration files from
  `UI::NotificationsCatalog#export_swift_scaffold`
- Info.plist shortcut fragments from
  `UI::HomeScreenQuickActions.export_plist_fragment`

### 3. Domain-to-platform mapping

Amber proper should be where domain logic decides:

- which process manager or domain event updates a widget timeline
- which event triggers a live activity update
- which domain action should become an App Shortcut
- which notification category belongs to which business flow
- which surface is available on which platform

This must not live as ad hoc logic in generated Swift files.

The correct layering is:

- Amber domain/process managers produce app intent/state
- asset_pipeline models/export helpers serialize native surface metadata
- Amber CLI writes host/extension files that consume those exports

### 4. Regeneration ergonomics

This is the highest leverage quality-of-life improvement.

The generator should be able to:

1. create a new native app
2. add a capability later
3. regenerate only the files it owns
4. avoid clobbering hand-edited app code

That means Amber CLI needs a clear ownership rule for generated files.

Recommended convention:

- generated files live under a clearly named subtree such as
  `mobile/apple/generated/` or `native/generated/`
- hand-editable wrapper files live beside them
- generated files include a header warning and are always safe to rewrite

Do not make the main target source tree impossible to maintain by mixing
generated and hand-edited files with no boundary.

## Recommended implementation plan

### Phase 1: Stabilize the declaration model

Goal: give Amber/Amber CLI a real app-shell manifest.

Deliverables:

- native capability manifest format
- parsing and validation
- tests for declaration loading
- one place where project intent is defined

Acceptance criteria:

- a generated native app can declare which Apple shell surfaces it uses
- the declaration can be read without loading Xcode or iOS host files

### Phase 2: Make native generation consume asset_pipeline exports

Goal: stop pretending the host files are handwritten forever.

Deliverables:

- WidgetKit generator integration
- ActivityKit generator integration
- AppIntents generator integration
- notifications export integration
- quick action plist generation

Acceptance criteria:

- generated project contains real scaffold output for enabled capabilities
- regenerating after a manifest change updates generated files deterministically

### Phase 3: Improve project ergonomics

Goal: reduce the “death by manual wiring” problem.

Deliverables:

- cleaner `amber new --type native` experience
- capability flags or post-create generator commands
- better README/getting-started guidance for generated apps
- stable file ownership conventions
- one command to regenerate native shell artifacts

Examples:

```bash
amber new my_app --type native
amber native add widgets
amber native add live-activities
amber native sync apple
```

These command names are illustrative, not final.

### Phase 4: Bring Amber runtime patterns up to the same level

Goal: make the framework itself speak in app/domain terms.

Deliverables:

- conventions for process managers publishing shell-surface state
- event bus patterns for app-shell updates
- docs/examples connecting domain events to widgets, notifications, shortcuts,
  and live activities

Acceptance criteria:

- a generated app has a clear place where domain events become native shell
  updates
- contributors do not have to invent the architecture each time

## Specific gaps to close in Amber CLI

### Gap A: Native generator is still largely imperative text assembly

`src/amber_cli/generators/native_app.cr` currently writes a large amount of
content directly from Crystal string literals.

That was a fine bootstrap move, but it is not the final ergonomic state.

Recommendation:

- keep the existing generator working
- add generator-owned templates for the Apple shell/export pieces
- gradually move repeated host-file content into reusable templates

Do not block progress on a full rewrite first.

### Gap B: The generator knows “native app” but not “native capabilities”

Right now the generator creates a large cross-platform scaffold, but it does
not yet let the developer express:

- “this app has widgets but not live activities”
- “this app uses notifications and App Shortcuts”
- “this app is macOS-only”

That missing capability declaration is the biggest conceptual gap.

### Gap C: There is no safe regeneration contract yet

If Amber CLI is going to own host wiring, it must also own a predictable
regeneration story.

This should be designed now, before more generated shell files spread through
the project.

## Recommended first agent task

If another agent starts immediately, have them do this first:

1. design the native capability manifest format for generated Amber apps
2. implement parser/validation for it in `amber_cli`
3. thread that manifest into `amber new --type native`
4. prove it with specs
5. write down which files are generator-owned vs hand-editable

Why this first:

- it gives every later generator feature a stable contract
- it prevents a pile of one-off flags and ad hoc YAML from forming
- it keeps `asset_pipeline` from becoming the wrong home for app-shell logic

## Recommended second agent task

After the manifest exists:

1. wire `UI::Widgets#export_widgetkit_scaffold` into generated Apple files
2. wire `UI::LiveActivities#export_activitykit_scaffold`
3. wire `UI::AppShortcuts#export_app_intents_scaffold`
4. wire `UI::NotificationsCatalog#export_swift_scaffold`

Do these as generator-owned files with deterministic output.

## What not to do

- do not move app-shell generation into `asset_pipeline`
- do not fake screenshots for system-owned surfaces in Amber
- do not make host wiring depend on manual copy/paste from docs
- do not mix generated extension code with developer-owned files without a
  rewrite boundary

## Concrete files to inspect first

In `amber_cli`:

- `src/amber_cli/commands/new.cr`
- `src/amber_cli/generators/native_app.cr`
- `spec/generators/native_app_spec.cr`
- `docs/NATIVE_APP_TESTING.md`

In `asset_pipeline`:

- `src/ui/widgets.cr`
- `src/ui/live_activities.cr`
- `src/ui/app_shortcuts.cr`
- `src/ui/notifications.cr`
- `src/ui/quick_actions.cr`
- `docs/APPLE_NATIVE_UI_STATUS.md`

## Bottom line

The UI library phase is good enough.

The next milestone is not “make more HIG screenshots.” It is:

- make Amber own the app-level declaration
- make Amber CLI own the generated host and extension wiring
- consume the exports that `asset_pipeline` already provides
- turn the current native foundation into a real application platform
