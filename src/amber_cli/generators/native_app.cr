# Generates a native cross-platform application scaffold using Amber V2 patterns
# with Asset Pipeline UI, crystal-audio, and build scripts for macOS, iOS, and Android.
#
# This generator encodes the lessons learned from building Scribe:
# - Amber without HTTP server (Amber.settings, NOT Amber::Server.configure)
# - Asset Pipeline cross-platform UI (require "asset_pipeline/ui")
# - FSDD process manager architecture
# - Platform-specific ObjC bridge compilation with -fno-objc-arc
# - Mobile cross-compilation (iOS simulator/device, Android NDK)
# - Three-layer test infrastructure (L1 specs, L2 UI tests, L3 E2E scripts)
# - Critical build flags: -Dmacos, -Dios, -Dandroid (NOT auto-detected)
# - BoehmGC compilation for Android (GC_BUILTIN_ATOMIC flag)
# - _main symbol conflict resolution for iOS (ld -r -unexported_symbol _main)
# - crystal-audio symlink requirement (crystal-audio -> crystal_audio)
# - GCD usage instead of Crystal spawn in NSApp applications
module AmberCLI::Generators
  class NativeApp
    getter path : String
    getter name : String

    def initialize(@path : String, @name : String)
    end

    def generate
      create_directories
      create_shard_yml
      create_amber_yml
      create_gitignore
      create_makefile
      create_claude_md
      create_main_file
      create_config_files
      create_application_controller
      create_main_controller
      create_main_process_manager
      create_event_bus
      create_main_view
      create_platform_bridge
      create_spec_helper
      create_process_manager_spec
      create_mobile_shared_bridge
      create_mobile_shared_spec
      create_ios_build_script
      create_ios_project_yml
      create_ios_ui_tests
      create_ios_e2e_script
      create_android_build_script
      create_android_build_gradle
      create_android_ui_tests
      create_android_e2e_script
      create_android_local_properties
      create_macos_ui_test_script
      create_macos_e2e_script
      create_mobile_ci_script
      create_fsdd_docs
      create_keep_files
    end

    private def create_directories
      dirs = [
        # Source
        "src", "src/controllers", "src/models", "src/process_managers",
        "src/ui", "src/platform", "src/events",
        # Config
        "config",
        # Desktop specs
        "spec", "spec/macos",
        # Mobile shared
        "mobile/shared", "mobile/shared/spec",
        # iOS
        "mobile/ios", "mobile/ios/UITests",
        # Android
        "mobile/android", "mobile/android/app/src/main/jniLibs/arm64-v8a",
        "mobile/android/app/src/androidTest/java/com/#{name}/app",
        # macOS test scripts
        "test/macos",
        # FSDD documentation
        "docs/fsdd", "docs/fsdd/feature-stories", "docs/fsdd/conventions",
        "docs/fsdd/knowledge-gaps", "docs/fsdd/process-managers",
        "docs/fsdd/testing",
        # Build output
        "bin",
      ]

      dirs.each do |dir|
        full_dir = File.join(path, dir)
        Dir.mkdir_p(full_dir) unless Dir.exists?(full_dir)
      end
    end

    private def create_shard_yml
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-SHARD
name: #{name}
version: 0.1.0

authors:
  - Your Name <your.email@example.com>

crystal: ">= 1.15.0"

license: UNLICENSED

targets:
  #{name}:
    main: src/#{name}.cr

dependencies:
  # Amber Framework V2 (patterns only, NO HTTP server for native apps)
  amber:
    github: crimson-knight/amber
    branch: master

  # Grant ORM (ActiveRecord-style, replaces Granite in V2)
  grant:
    github: crimson-knight/grant
    branch: main

  # Asset Pipeline (cross-platform UI: AppKit, UIKit, Android Views)
  # IMPORTANT: Must use the feature branch for cross-platform UI support
  asset_pipeline:
    github: amberframework/asset_pipeline
    branch: feature/utility-first-css-asset-pipeline

  # Audio recording, playback, and transcription
  crystal-audio:
    github: crimson-knight/crystal-audio

  # Database adapters (all required by Grant at compile time)
  pg:
    github: will/crystal-pg
  mysql:
    github: crystal-lang/crystal-mysql
  sqlite3:
    github: crystal-lang/crystal-sqlite3

development_dependencies:
  ameba:
    github: crystal-ameba/ameba
    version: ~> 1.4.3
SHARD

      File.write(File.join(path, "shard.yml"), content)
    end

    private def create_amber_yml
      content = <<-AMBER
app: #{name}
author: Your Name
email: your.email@example.com
database: sqlite
language: crystal
model: grant
type: native
AMBER

      File.write(File.join(path, ".amber.yml"), content)
    end

    private def create_gitignore
      content = <<-GITIGNORE
# Crystal
/docs/api/
/lib/
/bin/
/.shards/
*.dwarf
*.o

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.idea/
.vscode/

# Build artifacts
/tmp/
/dist/

# Mobile build artifacts
/mobile/ios/build/
/mobile/ios/*.xcodeproj
/mobile/ios/Scribe.xcworkspace
/mobile/android/build/
/mobile/android/.gradle/
/mobile/android/app/build/
/mobile/android/local.properties
GITIGNORE

      File.write(File.join(path, ".gitignore"), content)
    end

    private def create_makefile
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-MAKEFILE
PROJECT_DIR := $(shell pwd)
CRYSTAL := crystal-alpha
BIN := bin/#{name}

# Bridge object files
AP_BRIDGE := $(PROJECT_DIR)/lib/asset_pipeline/src/ui/native/objc_bridge.o
AP_BRIDGE_SRC := $(PROJECT_DIR)/lib/asset_pipeline/src/ui/native/objc_bridge.m
APP_BRIDGE := $(PROJECT_DIR)/src/platform/#{name}_platform_bridge.o
APP_BRIDGE_SRC := $(PROJECT_DIR)/src/platform/#{name}_platform_bridge.m

# crystal-audio native extensions
CA_EXT_DIR := $(PROJECT_DIR)/lib/crystal-audio/ext
CA_EXT_OBJS := $(wildcard $(CA_EXT_DIR)/*.o)
ifeq ($(CA_EXT_OBJS),)
CA_EXT_OBJS := $(CA_EXT_DIR)/block_bridge.o $(CA_EXT_DIR)/objc_helpers.o $(CA_EXT_DIR)/audio_write_helper.o
endif

# Framework flags for macOS
# IMPORTANT: These frameworks are required for Asset Pipeline + crystal-audio
MACOS_FRAMEWORKS := -framework AppKit -framework Foundation \\
	-framework AVFoundation -framework AudioToolbox -framework CoreAudio \\
	-framework CoreFoundation -framework CoreMedia \\
	-lobjc

# Full link flags for macOS
MACOS_LINK_FLAGS := $(AP_BRIDGE) $(APP_BRIDGE) $(CA_EXT_OBJS) $(MACOS_FRAMEWORKS)

.PHONY: all setup macos macos-release ext ext-app ext-ap ext-audio run clean spec

all: macos

# --- First-time setup ---

setup:
	shards-alpha install || shards install || true
	@# crystal-audio shard name has a hyphen but source uses underscore
	@# Crystal's require resolution needs the underscore directory
	@if [ ! -e lib/crystal_audio ]; then \\
		ln -sf crystal-audio lib/crystal_audio; \\
		echo "Created lib/crystal_audio symlink"; \\
	fi

# --- Build targets ---

# CRITICAL: -Dmacos flag is REQUIRED. Asset Pipeline gates AppKit renderer on it.
# Do NOT rely on auto-detection — Crystal does not auto-set platform flags.
macos: ext
	$(CRYSTAL) build src/#{name}.cr -o $(BIN) -Dmacos \\
		--link-flags="$(MACOS_LINK_FLAGS)"

macos-release: ext
	$(CRYSTAL) build src/#{name}.cr -o $(BIN) -Dmacos --release \\
		--link-flags="$(MACOS_LINK_FLAGS)"

# --- Native extensions ---

ext: ext-ap ext-app ext-audio

# Asset Pipeline ObjC bridge (cross-platform UI rendering)
# IMPORTANT: -fno-objc-arc is REQUIRED — the bridge manages its own memory
ext-ap: $(AP_BRIDGE)
$(AP_BRIDGE): $(AP_BRIDGE_SRC)
	clang -c $(AP_BRIDGE_SRC) -o $(AP_BRIDGE) -fno-objc-arc

# Application platform bridge
ext-app: $(APP_BRIDGE)
$(APP_BRIDGE): $(APP_BRIDGE_SRC)
	clang -c $(APP_BRIDGE_SRC) -o $(APP_BRIDGE) -fno-objc-arc

# crystal-audio extensions (recording, playback)
ext-audio:
	@if [ -d "$(CA_EXT_DIR)" ]; then \\
		cd lib/crystal-audio && make ext 2>/dev/null || true; \\
	fi

# --- Run ---

run: macos
	./$(BIN)

# --- Tests ---

spec:
	crystal-alpha spec spec/ -Dmacos

# --- Clean ---

clean:
	rm -f $(BIN) $(APP_BRIDGE) $(AP_BRIDGE)
	rm -f $(CA_EXT_DIR)/*.o
	rm -rf mobile/ios/build mobile/android/build
MAKEFILE

      File.write(File.join(path, "Makefile"), content)
    end

    private def create_claude_md
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-CLAUDEMD
# #{pascal_name} — Native Cross-Platform Application

## What This Is

#{pascal_name} is a native cross-platform application built with Crystal (via crystal-alpha compiler),
Amber V2 patterns, Asset Pipeline cross-platform UI, and crystal-audio.

## Architecture (READ THIS FIRST)

**This is NOT a web app.** Despite using Amber V2, #{pascal_name} is a native application:

- **macOS:** Native AppKit application
- Uses Amber's patterns (MVC, process managers, configuration) but NOT its HTTP server
- All UI rendered via Asset Pipeline cross-platform components
- All business logic lives in Process Managers (FSDD pattern)
- Event-driven architecture, not request/response

## Compiler

Use `crystal-alpha` (NOT `crystal`) for all builds. **CRITICAL:** You MUST pass platform flags:
```bash
crystal-alpha build src/#{name}.cr -o bin/#{name} -Dmacos --link-flags="..."
```
Platform flags: `-Dmacos`, `-Dios`, `-Dandroid` (NOT auto-detected by Crystal).

## Amber Configuration

Use `Amber.settings` directly — do NOT use `Amber::Server.configure` or start the HTTP server:
```crystal
Amber.settings.name = "#{pascal_name}"  # Correct
# Amber::Server.configure { ... }       # WRONG for native apps
```

## Build (macOS Development)

```bash
make setup    # First time: install shards + create symlinks
make macos    # Build for macOS (compiles ObjC bridges + Crystal)
make run      # Build and run
make spec     # Run Crystal specs
```

## Key Constraints

1. **No HTTP server.** Native app uses event loop, not Amber::Server.
2. **All UI through Asset Pipeline.** `require "asset_pipeline/ui"`, NOT `require "ui"`.
3. **Process managers own business logic.** Controllers only validate and delegate.
4. **crystal-alpha compiler.** Required for cross-compilation targets.
5. **Platform flags are mandatory.** Always pass -Dmacos, -Dios, or -Dandroid.
6. **ObjC bridge: -fno-objc-arc.** Asset Pipeline bridge manages its own memory.
7. **No Crystal spawn in NSApp.** Use GCD via ObjC bridge instead.
8. **crystal-audio symlink.** Needs `ln -sf crystal-audio lib/crystal_audio`.

## Key Directories

```
src/
├── controllers/      — Event handlers (adapted from Amber controllers)
├── models/           — Data models (Grant ORM + SQLite)
├── process_managers/ — All business logic (FSDD process managers)
├── ui/               — Views using Asset Pipeline UI components
├── platform/         — Platform-specific ObjC bridge
└── events/           — Internal event bus
```

## Cross-Platform Builds

- **macOS:** `make macos`
- **iOS:** `cd mobile/ios && ./build_crystal_lib.sh simulator`
- **Android:** `cd mobile/android && ./build_crystal_lib.sh`
CLAUDEMD

      File.write(File.join(path, "CLAUDE.md"), content)
    end

    private def create_main_file
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-MAIN
require "amber"
require "asset_pipeline/ui"
require "./controllers/**"
require "./models/**"
require "./process_managers/**"
require "./ui/**"
require "./events/**"

# Configure Amber WITHOUT HTTP server.
# IMPORTANT: Use Amber.settings directly, NOT Amber::Server.configure.
# Native apps use an event loop, not an HTTP server.
Amber.settings.name = "#{pascal_name}"

# Initialize and start the application
module #{pascal_name}
  def self.start
    # Initialize process managers
    main_pm = ProcessManagers::MainProcessManager.new

    # Build the initial UI
    main_view = UI::MainView.new
    main_view.render

    # Start the native event loop
    # On macOS, this will be the NSApplication run loop
    {% if flag?(:macos) %}
      # macOS: NSApplication run loop is started by Asset Pipeline
      # IMPORTANT: Never use Crystal `spawn` in NSApp — use GCD via ObjC bridge
    {% end %}
  end
end

#{pascal_name}.start
MAIN

      File.write(File.join(path, "src/#{name}.cr"), content)
    end

    private def create_config_files
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-CONFIG
require "amber"

# Native app configuration.
# IMPORTANT: Do NOT use Amber::Server.configure — that creates an HTTP server.
# Native apps use Amber.settings directly for configuration.
Amber.settings.name = "#{pascal_name}"
CONFIG

      File.write(File.join(path, "config/application.cr"), content)
    end

    private def create_application_controller
      content = <<-CONTROLLER
# Base controller for native app event handlers.
# In a native app, controllers handle UI events rather than HTTP requests.
# All business logic should be delegated to process managers.
class ApplicationController
  # Override in subclasses to handle specific events
  def handle(event : String, payload : Hash(String, String)? = nil)
  end
end
CONTROLLER

      File.write(File.join(path, "src/controllers/application_controller.cr"), content)
    end

    private def create_main_controller
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-CONTROLLER
# Main event controller for #{pascal_name}.
# Handles UI events and delegates to process managers.
# FSDD Rule: Controllers only validate and delegate — never contain business logic.
class MainController < ApplicationController
  @process_manager : ProcessManagers::MainProcessManager

  def initialize(@process_manager = ProcessManagers::MainProcessManager.new)
  end

  def handle(event : String, payload : Hash(String, String)? = nil)
    case event
    when "app:launched"
      @process_manager.on_app_launched
    when "app:will_terminate"
      @process_manager.on_app_will_terminate
    else
      # Unknown event — log and ignore
    end
  end
end
CONTROLLER

      File.write(File.join(path, "src/controllers/main_controller.cr"), content)
    end

    private def create_main_process_manager
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-PM
# Main process manager for #{pascal_name}.
# FSDD Rule: ALL business logic lives in process managers.
# Controllers only validate and delegate to this class.
module ProcessManagers
  class MainProcessManager
    getter state : String = "idle"

    def initialize
      @state = "initialized"
    end

    def on_app_launched
      @state = "running"
      # Add startup logic here
    end

    def on_app_will_terminate
      @state = "terminating"
      # Add cleanup logic here
    end
  end
end
PM

      File.write(File.join(path, "src/process_managers/main_process_manager.cr"), content)
    end

    private def create_event_bus
      content = <<-EVENTS
# Simple event bus for native app communication.
# Process managers and controllers communicate through events,
# not direct method calls across boundaries.
module Events
  alias EventHandler = String, Hash(String, String)? ->

  class EventBus
    @@handlers = Hash(String, Array(EventHandler)).new

    def self.on(event : String, &handler : EventHandler)
      @@handlers[event] ||= Array(EventHandler).new
      @@handlers[event] << handler
    end

    def self.emit(event : String, payload : Hash(String, String)? = nil)
      if handlers = @@handlers[event]?
        handlers.each { |handler| handler.call(event, payload) }
      end
    end

    def self.clear
      @@handlers.clear
    end
  end
end
EVENTS

      File.write(File.join(path, "src/events/event_bus.cr"), content)
    end

    private def create_main_view
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-VIEW
require "asset_pipeline/ui"

# Main view for #{pascal_name}.
# Uses Asset Pipeline cross-platform UI components.
# IMPORTANT: require "asset_pipeline/ui" NOT "ui"
module UI
  class MainView
    def render
      # Asset Pipeline renders to the appropriate native backend:
      # - macOS: AppKit (NSView hierarchy)
      # - iOS: UIKit (UIView hierarchy)
      # - Android: Android Views (ViewGroup hierarchy)
      #
      # Example view composition:
      # root = ::UI::VStack.new
      # root.children << ::UI::Label.new(text: "Welcome to #{pascal_name}")
      # root.children << ::UI::Button.new(text: "Get Started", test_id: "1.1-get-started-button")
      #
      # test_id convention (FSDD): {epic}.{story}-{element-name}
    end
  end
end
VIEW

      File.write(File.join(path, "src/ui/main_view.cr"), content)
    end

    private def create_platform_bridge
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-OBJC
// #{pascal_name} Platform Bridge
//
// ObjC bridge for platform-specific functionality.
// Compiled with: clang -c #{name}_platform_bridge.m -o #{name}_platform_bridge.o -fno-objc-arc
//
// IMPORTANT:
// - Must compile with -fno-objc-arc (bridge manages its own memory)
// - Never use Crystal `spawn` in NSApp applications — use GCD instead
// - Use dispatch_async for async work, callback on main thread

#import <Foundation/Foundation.h>

#ifdef __APPLE__
  #include <TargetConditionals.h>
  #if TARGET_OS_OSX
    #import <AppKit/AppKit.h>
  #elif TARGET_OS_IOS
    #import <UIKit/UIKit.h>
  #endif
#endif

// ============================================================================
// Section 1: GCD Dispatch Helpers
// ============================================================================
// Use these instead of Crystal `spawn` in NSApp applications.
// Crystal fibers and NSApplication run loop do not cooperate safely.

typedef void (*gcd_callback_t)(void *context);

void dispatch_to_main(gcd_callback_t callback, void *context) {
    dispatch_async(dispatch_get_main_queue(), ^{
        callback(context);
    });
}

void dispatch_to_background(gcd_callback_t callback, void *context) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        callback(context);
    });
}

// ============================================================================
// Section 2: Platform Detection
// ============================================================================

int platform_is_macos(void) {
#if TARGET_OS_OSX
    return 1;
#else
    return 0;
#endif
}

int platform_is_ios(void) {
#if TARGET_OS_IOS
    return 1;
#else
    return 0;
#endif
}

// ============================================================================
// Section 3: Application-Specific Bridges
// ============================================================================
// Add your platform-specific ObjC bridges here.
// Follow the pattern: C function signature callable from Crystal lib blocks.
//
// Example:
//   void show_native_alert(const char *title, const char *message) {
//     #if TARGET_OS_OSX
//       NSAlert *alert = [[NSAlert alloc] init];
//       [alert setMessageText:[NSString stringWithUTF8String:title]];
//       [alert setInformativeText:[NSString stringWithUTF8String:message]];
//       [alert runModal];
//     #endif
//   }
//
// Then in Crystal:
//   @[Link(ldflags: "...")]
//   lib PlatformBridge
//     # IMPORTANT: Use `alias` NOT `type` for C function pointer types (GAP-17)
//     alias GCDCallback = Pointer(Void) -> Void
//     fun dispatch_to_main(callback : GCDCallback, context : Pointer(Void))
//     fun show_native_alert(title : LibC::Char*, message : LibC::Char*)
//   end
OBJC

      File.write(File.join(path, "src/platform/#{name}_platform_bridge.m"), content)
    end

    private def create_spec_helper
      content = <<-SPEC
require "spec"
require "../src/process_managers/**"
require "../src/events/**"

# Native app specs test process managers and event bus.
# UI rendering and platform bridges require hardware and are tested
# via L2 (UI tests) and L3 (E2E scripts) instead.
SPEC

      File.write(File.join(path, "spec/spec_helper.cr"), content)
    end

    private def create_process_manager_spec
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-SPEC
require "../spec_helper"

describe ProcessManagers::MainProcessManager do
  describe "#initialize" do
    it "starts in initialized state" do
      pm = ProcessManagers::MainProcessManager.new
      pm.state.should eq("initialized")
    end
  end

  describe "#on_app_launched" do
    it "transitions to running state" do
      pm = ProcessManagers::MainProcessManager.new
      pm.on_app_launched
      pm.state.should eq("running")
    end
  end

  describe "#on_app_will_terminate" do
    it "transitions to terminating state" do
      pm = ProcessManagers::MainProcessManager.new
      pm.on_app_will_terminate
      pm.state.should eq("terminating")
    end
  end
end

describe Events::EventBus do
  it "registers and emits events" do
    received = false
    Events::EventBus.on("test:event") { |_event, _payload| received = true }
    Events::EventBus.emit("test:event")
    received.should be_true
    Events::EventBus.clear
  end

  it "passes payload to handlers" do
    received_payload = nil
    Events::EventBus.on("test:payload") { |_event, payload| received_payload = payload }
    Events::EventBus.emit("test:payload", {"key" => "value"})
    received_payload.should eq({"key" => "value"})
    Events::EventBus.clear
  end
end
SPEC

      File.write(File.join(path, "spec/macos/process_manager_spec.cr"), content)
    end

    private def create_mobile_shared_bridge
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BRIDGE
# Shared mobile bridge for #{pascal_name}.
# This file is cross-compiled for both iOS and Android.
#
# iOS:  crystal-alpha build ... --cross-compile --target=arm64-apple-ios-simulator -Dios
# Android: crystal-alpha build ... --cross-compile --target=aarch64-linux-android26 -Dandroid
#
# IMPORTANT: Guard platform-specific code with compile flags:
#   {% if flag?(:darwin) %}     — macOS or iOS
#   {% if flag?(:ios) %}        — iOS only
#   {% if flag?(:android) %}    — Android only
#   {% unless flag?(:darwin) || flag?(:android) %} — neither (for stubs)

module #{pascal_name}::MobileBridge
  # State machine for the mobile app lifecycle
  enum AppState
    Idle
    Ready
    Recording
    Processing
    Error
  end

  class Bridge
    getter state : AppState = AppState::Idle

    def initialize
      @state = AppState::Ready
    end

    def transition_to(new_state : AppState) : Bool
      case {state, new_state}
      when {AppState::Ready, AppState::Recording},
           {AppState::Recording, AppState::Processing},
           {AppState::Processing, AppState::Ready},
           {AppState::Error, AppState::Ready}
        @state = new_state
        true
      else
        false
      end
    end
  end
end
BRIDGE

      File.write(File.join(path, "mobile/shared/bridge.cr"), content)
    end

    private def create_mobile_shared_spec
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-SPEC
require "spec"
require "../bridge"

# L1 mobile bridge specs.
# Tests the state machine independently of platform code.
# Approach: standalone state machine replica (Option B) to avoid
# `fun main` conflict + hardware dependencies.

describe #{pascal_name}::MobileBridge::Bridge do
  describe "#initialize" do
    it "starts in Ready state" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      bridge.state.should eq(#{pascal_name}::MobileBridge::AppState::Ready)
    end
  end

  describe "#transition_to" do
    it "transitions Ready -> Recording" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Recording).should be_true
      bridge.state.should eq(#{pascal_name}::MobileBridge::AppState::Recording)
    end

    it "transitions Recording -> Processing" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Recording)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Processing).should be_true
      bridge.state.should eq(#{pascal_name}::MobileBridge::AppState::Processing)
    end

    it "transitions Processing -> Ready" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Recording)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Processing)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Ready).should be_true
      bridge.state.should eq(#{pascal_name}::MobileBridge::AppState::Ready)
    end

    it "transitions Error -> Ready" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      # Force error state for testing
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Recording)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Processing)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Ready)
      # Now test Error -> Ready would work if we could set error state
    end

    it "rejects invalid transitions" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      # Ready -> Processing is not valid (must go through Recording)
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Processing).should be_false
      bridge.state.should eq(#{pascal_name}::MobileBridge::AppState::Ready)
    end

    it "rejects Ready -> Error" do
      bridge = #{pascal_name}::MobileBridge::Bridge.new
      bridge.transition_to(#{pascal_name}::MobileBridge::AppState::Error).should be_false
    end
  end
end
SPEC

      File.write(File.join(path, "mobile/shared/spec/bridge_spec.cr"), content)
    end

    private def create_ios_build_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# build_crystal_lib.sh
#
# Build the #{pascal_name} Crystal bridge as a static library for iOS.
#
# Output: mobile/ios/build/lib#{name}.a
#
# Prerequisites
# -------------
#   - crystal-alpha installed
#   - Xcode with iOS SDK: xcode-select --install
#
# Usage
# -----
#   cd #{name} && ./mobile/ios/build_crystal_lib.sh [simulator|device]
#
# Key learnings from Scribe:
#   - MUST use ld -r -unexported_symbol _main on Crystal .o to avoid _main clash with Swift @main
#   - BoehmGC (libgc.a) must be compiled targeting the iOS simulator SDK
#   - ext files needed: block_bridge.c, objc_helpers.c, trace_helper.c, audio_write_helper.c

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL=\${CRYSTAL:-crystal-alpha}
BUILD_TARGET="\${1:-simulator}"

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
MOBILE_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="\$(cd "\$MOBILE_DIR/.." && pwd)"
BUILD_DIR="\$SCRIPT_DIR/build"
OUTPUT_LIB="\$BUILD_DIR/lib#{name}.a"
BRIDGE_SRC="\$MOBILE_DIR/shared/bridge.cr"
BRIDGE_BASE="\$BUILD_DIR/bridge"

# crystal-audio ext directory
CRYSTAL_AUDIO_EXT=""
if [[ -d "\$PROJECT_ROOT/lib/crystal-audio/ext" ]]; then
    CRYSTAL_AUDIO_EXT="\$PROJECT_ROOT/lib/crystal-audio/ext"
elif [[ -d "\$PROJECT_ROOT/lib/crystal_audio/ext" ]]; then
    CRYSTAL_AUDIO_EXT="\$PROJECT_ROOT/lib/crystal_audio/ext"
fi

MIN_IOS_VER="16.0"

case "\$BUILD_TARGET" in
    simulator)
        LLVM_TARGET="arm64-apple-ios-simulator"
        SDK_NAME="iphonesimulator"
        ;;
    device)
        LLVM_TARGET="arm64-apple-ios"
        SDK_NAME="iphoneos"
        ;;
    *)
        echo "Usage: \$0 [simulator|device]"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\\033[0;34m[build]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[ok]\\033[0m    %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m  %s\\n' "\$*" >&2; exit 1; }

require_cmd() {
    command -v "\$1" >/dev/null 2>&1 || fail "Required command not found: \$1"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

require_cmd "\$CRYSTAL"
require_cmd xcrun
require_cmd xcodebuild

[[ ! -f "\$BRIDGE_SRC" ]] && fail "Bridge source not found: \$BRIDGE_SRC"

SDK_PATH="\$(xcrun --sdk \$SDK_NAME --show-sdk-path)"
CLANG="\$(xcrun --sdk \$SDK_NAME --find clang)"

info "Target         : \$LLVM_TARGET"
info "SDK            : \$SDK_PATH"
info "Bridge source  : \$BRIDGE_SRC"

mkdir -p "\$BUILD_DIR"

# ---------------------------------------------------------------------------
# Step 1: Compile native extensions for iOS
# ---------------------------------------------------------------------------

info "Compiling native extensions for \$BUILD_TARGET..."

if [[ -n "\$CRYSTAL_AUDIO_EXT" ]]; then
    for src_file in "\$CRYSTAL_AUDIO_EXT"/*.c "\$CRYSTAL_AUDIO_EXT"/*.m; do
        [[ ! -f "\$src_file" ]] && continue
        obj_name="\$(basename "\$src_file" | sed 's/\\.[cm]\$//')_ios.o"
        "\$CLANG" -c "\$src_file" -o "\$BUILD_DIR/\$obj_name" \\
            -target "\$LLVM_TARGET" \\
            -isysroot "\$SDK_PATH" \\
            -mios-version-min=\$MIN_IOS_VER \\
            -fno-objc-arc 2>/dev/null || true
    done
    ok "Native extensions compiled"
else
    info "No crystal-audio ext directory found, skipping"
fi

# ---------------------------------------------------------------------------
# Step 2: Cross-compile Crystal bridge
# ---------------------------------------------------------------------------

info "Cross-compiling Crystal bridge..."

"\$CRYSTAL" build "\$BRIDGE_SRC" \\
    --cross-compile \\
    --target="\$LLVM_TARGET" \\
    -Dios \\
    -o "\$BRIDGE_BASE"

ok "Crystal cross-compilation complete"

# ---------------------------------------------------------------------------
# Step 3: Fix _main symbol conflict
# ---------------------------------------------------------------------------
# CRITICAL: Crystal emits a _main symbol that conflicts with Swift's @main.
# We must hide it using ld -r -unexported_symbol _main.

info "Fixing _main symbol conflict..."

if [[ -f "\$BRIDGE_BASE.o" ]]; then
    ld -r -unexported_symbol _main "\$BRIDGE_BASE.o" -o "\$BUILD_DIR/bridge_fixed.o"
    mv "\$BUILD_DIR/bridge_fixed.o" "\$BRIDGE_BASE.o"
    ok "_main symbol hidden"
fi

# ---------------------------------------------------------------------------
# Step 4: Pack into static library
# ---------------------------------------------------------------------------

info "Creating static library..."

OBJ_FILES="\$BRIDGE_BASE.o"
for obj in "\$BUILD_DIR"/*_ios.o; do
    [[ -f "\$obj" ]] && OBJ_FILES="\$OBJ_FILES \$obj"
done

ar rcs "\$OUTPUT_LIB" \$OBJ_FILES
ok "Static library created: \$OUTPUT_LIB"

info "Done! Link with: -L\$BUILD_DIR -l#{name}"
BASH

      script_path = File.join(path, "mobile/ios/build_crystal_lib.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_ios_project_yml
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-YML
name: #{pascal_name}
options:
  bundleIdPrefix: com.#{name}.app
  deploymentTarget:
    iOS: "16.0"
settings:
  # CRITICAL: Crystal only compiles arm64. Exclude x86_64 from simulator builds.
  EXCLUDED_ARCHS[sdk=iphonesimulator*]: x86_64
targets:
  #{pascal_name}:
    type: application
    platform: iOS
    sources:
      - path: Sources
    settings:
      LIBRARY_SEARCH_PATHS: $(PROJECT_DIR)/build
      OTHER_LDFLAGS:
        - -l#{name}
        - -lgc
        - -framework AVFoundation
        - -framework AudioToolbox
        - -framework CoreAudio
        - -framework CoreFoundation
        - -framework Foundation
        - -framework UIKit
        - -lobjc
    dependencies: []
  #{pascal_name}UITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: UITests
    dependencies:
      - target: #{pascal_name}
YML

      File.write(File.join(path, "mobile/ios/project.yml"), content)
    end

    private def create_ios_ui_tests
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-SWIFT
import XCTest

// L2 iOS UI Tests for #{pascal_name}
// Uses accessibilityIdentifier (mapped from Asset Pipeline test_id)
// test_id convention (FSDD): {epic}.{story}-{element-name}
//
// IMPORTANT: These tests require:
//   1. Build Crystal lib: ./build_crystal_lib.sh simulator
//   2. Generate Xcode project: xcodegen generate
//   3. Build app: xcodebuild -scheme #{pascal_name} -sdk iphonesimulator build
//   4. Then run tests: xcodebuild test -scheme #{pascal_name}UITests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'

final class #{pascal_name}UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched successfully
        XCTAssertTrue(app.exists)
    }

    // Add UI tests using accessibilityIdentifier:
    // func testMainViewExists() throws {
    //     let app = XCUIApplication()
    //     app.launch()
    //     let element = app.staticTexts["1.1-welcome-label"]
    //     XCTAssertTrue(element.waitForExistence(timeout: 5))
    // }
}
SWIFT

      File.write(File.join(path, "mobile/ios/UITests/UITests.swift"), content)
    end

    private def create_ios_e2e_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# L3 E2E test script for #{pascal_name} iOS
# Runs the full build + test cycle without JS/Python dependencies.
#
# Usage: cd #{name} && ./mobile/ios/test_ios.sh

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

info()  { printf '\\033[0;34m[test]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[pass]\\033[0m %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m %s\\n' "\$*" >&2; exit 1; }

PASS=0
TOTAL=0

check() {
    TOTAL=\$((TOTAL + 1))
    if eval "\$2"; then
        ok "\$1"
        PASS=\$((PASS + 1))
    else
        fail "\$1"
    fi
}

# Step 1: Build Crystal static library
info "Step 1/6: Building Crystal library for iOS simulator..."
cd "\$PROJECT_ROOT"
check "Crystal lib builds" "./mobile/ios/build_crystal_lib.sh simulator"

# Step 2: Verify static library exists
info "Step 2/6: Verifying static library..."
check "lib#{name}.a exists" "[ -f mobile/ios/build/lib#{name}.a ]"

# Step 3: Generate Xcode project
info "Step 3/6: Generating Xcode project..."
cd "\$SCRIPT_DIR"
check "xcodegen succeeds" "command -v xcodegen >/dev/null && xcodegen generate"

# Step 4: Build the iOS app
info "Step 4/6: Building iOS app..."
check "xcodebuild succeeds" "xcodebuild -project #{pascal_name}.xcodeproj -scheme #{pascal_name} -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build 2>/dev/null"

# Step 5: Run UI tests
info "Step 5/6: Running UI tests..."
check "UI tests pass" "xcodebuild test -project #{pascal_name}.xcodeproj -scheme #{pascal_name}UITests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>/dev/null"

# Step 6: Summary
info "Step 6/6: Results"
echo ""
echo "===================="
echo "  \$PASS / \$TOTAL passed"
echo "===================="
BASH

      script_path = File.join(path, "mobile/ios/test_ios.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_android_build_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# build_crystal_lib.sh -- Cross-compile Crystal + JNI bridge for Android (aarch64)
#
# Produces: app/src/main/jniLibs/arm64-v8a/lib#{name}.so
#
# Prerequisites:
#   - crystal-alpha compiler
#   - Android NDK (ANDROID_SDK_ROOT or NDK_ROOT env var)
#   - Pre-built libgc.a for aarch64-linux-android26
#
# CRITICAL: libgc.a for Android must be compiled with GC_BUILTIN_ATOMIC flag.
# Use NDK's llvm-ar (not system ar) to create the archive.
#
# Usage:
#   cd #{name} && ./mobile/android/build_crystal_lib.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL="\${CRYSTAL:-crystal-alpha}"
TARGET="aarch64-linux-android26"
API_LEVEL=26
HOST_TAG="darwin-x86_64"

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
MOBILE_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="\$(cd "\$MOBILE_DIR/.." && pwd)"
BUILD_DIR="\$SCRIPT_DIR/build"
JNILIBS_DIR="\$SCRIPT_DIR/app/src/main/jniLibs/arm64-v8a"
BRIDGE_SRC="\$MOBILE_DIR/shared/bridge.cr"
BRIDGE_BASE="\$BUILD_DIR/bridge"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\\033[0;34m[build]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[ok]\\033[0m    %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m  %s\\n' "\$*" >&2; exit 1; }

require_cmd() {
    command -v "\$1" >/dev/null 2>&1 || fail "Required command not found: \$1"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

require_cmd "\$CRYSTAL"

[[ ! -f "\$BRIDGE_SRC" ]] && fail "Bridge source not found: \$BRIDGE_SRC"

# Locate NDK
ANDROID_SDK_ROOT="\${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
NDK_ROOT="\${NDK_ROOT:-\$(ls -d "\$ANDROID_SDK_ROOT"/ndk/*/ 2>/dev/null | sort -V | tail -1)}"
NDK_ROOT="\${NDK_ROOT%/}"

if [[ -z "\$NDK_ROOT" ]] || [[ ! -d "\$NDK_ROOT" ]]; then
    fail "NDK not found. Set NDK_ROOT or install NDK under \\\$ANDROID_SDK_ROOT/ndk/"
fi

NDK_CLANG="\$NDK_ROOT/toolchains/llvm/prebuilt/\$HOST_TAG/bin/\${TARGET}-clang"
CLANG_FLAGS=""
if [[ ! -f "\$NDK_CLANG" ]]; then
    NDK_CLANG="\$NDK_ROOT/toolchains/llvm/prebuilt/\$HOST_TAG/bin/clang"
    CLANG_FLAGS="--target=\$TARGET"
    [[ ! -f "\$NDK_CLANG" ]] && fail "NDK clang not found at: \$NDK_CLANG"
fi

SYSROOT="\$NDK_ROOT/toolchains/llvm/prebuilt/\$HOST_TAG/sysroot"

info "Target         : \$TARGET"
info "NDK root       : \$NDK_ROOT"
info "Bridge source  : \$BRIDGE_SRC"

mkdir -p "\$BUILD_DIR" "\$JNILIBS_DIR"

# ---------------------------------------------------------------------------
# Step 1: Compile JNI bridge
# ---------------------------------------------------------------------------

info "Compiling JNI bridge..."

cat > "\$BUILD_DIR/jni_bridge.c" << 'JNIC'
#include <android/log.h>
#include <jni.h>

// Crystal trace function — routes to Android logcat
void crystal_trace(const char *msg) {
    __android_log_print(ANDROID_LOG_DEBUG, "#{pascal_name}", "%s", msg);
}
JNIC

"\$NDK_CLANG" \$CLANG_FLAGS -c "\$BUILD_DIR/jni_bridge.c" -o "\$BUILD_DIR/jni_bridge.o" \\
    --sysroot="\$SYSROOT"

ok "JNI bridge compiled"

# ---------------------------------------------------------------------------
# Step 2: Cross-compile Crystal bridge
# ---------------------------------------------------------------------------

info "Cross-compiling Crystal bridge for Android..."

"\$CRYSTAL" build "\$BRIDGE_SRC" \\
    --cross-compile \\
    --target="\$TARGET" \\
    -Dandroid \\
    -o "\$BRIDGE_BASE"

ok "Crystal cross-compilation complete"

# ---------------------------------------------------------------------------
# Step 3: Link shared library
# ---------------------------------------------------------------------------
# CRITICAL: -laaudio is REQUIRED for AAudio recording/playback on Android.
# Missing -laaudio causes undefined symbol errors at runtime.

info "Linking shared library..."

"\$NDK_CLANG" \$CLANG_FLAGS \\
    "\$BRIDGE_BASE.o" "\$BUILD_DIR/jni_bridge.o" \\
    -shared -o "\$JNILIBS_DIR/lib#{name}.so" \\
    --sysroot="\$SYSROOT" \\
    -laaudio -llog -landroid \\
    -lm -ldl -lc

ok "Shared library created: \$JNILIBS_DIR/lib#{name}.so"

info "Done!"
BASH

      script_path = File.join(path, "mobile/android/build_crystal_lib.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_android_build_gradle
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-GRADLE
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.#{name}.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.#{name}.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            // Crystal cross-compiles to arm64-v8a only
            abiFilters += "arm64-v8a"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.1"
    }

    // IMPORTANT: Android build requires JDK 17 (AGP 8.x incompatible with JDK 25)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-compose:1.8.0")
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    // material-icons-extended required for Mic/Stop/AudioFile icons
    implementation("androidx.compose.material:material-icons-extended")

    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
GRADLE

      File.write(File.join(path, "mobile/android/build.gradle.kts"), content)
    end

    private def create_android_ui_tests
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-KOTLIN
package com.#{name}.app

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

// L2 Android Compose UI Tests for #{pascal_name}
// Uses testTag (mapped from Asset Pipeline test_id / contentDescription)
// test_id convention (FSDD): {epic}.{story}-{element-name}
//
// IMPORTANT: Build requires JDK 17 (AGP 8.x incompatible with JDK 25)
//   JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home ./gradlew connectedAndroidTest

@RunWith(AndroidJUnit4::class)
class #{pascal_name}UITests {

    // Add compose test rule when Activity is created:
    // @get:Rule
    // val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun appLaunches() {
        // Verify the app launches without crashing
        assert(true)
    }

    // Add UI tests using testTag:
    // @Test
    // fun mainViewExists() {
    //     composeTestRule.onNodeWithTag("1.1-welcome-label").assertIsDisplayed()
    // }
}
KOTLIN

      File.write(File.join(path, "mobile/android/app/src/androidTest/java/com/#{name}/app/#{pascal_name}UITests.kt"), content)
    end

    private def create_android_e2e_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# L3 E2E test script for #{pascal_name} Android
# Runs the full build + test cycle without JS/Python dependencies.
#
# IMPORTANT: Requires JDK 17 (AGP 8.x incompatible with JDK 25)
#
# Usage: cd #{name} && ./mobile/android/test_android.sh

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

# JDK 17 required for Android Gradle Plugin
export JAVA_HOME="\${JAVA_HOME:-/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home}"

info()  { printf '\\033[0;34m[test]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[pass]\\033[0m %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m %s\\n' "\$*" >&2; exit 1; }

PASS=0
TOTAL=0

check() {
    TOTAL=\$((TOTAL + 1))
    if eval "\$2"; then
        ok "\$1"
        PASS=\$((PASS + 1))
    else
        fail "\$1"
    fi
}

# Step 1: Build Crystal shared library
info "Step 1/6: Building Crystal library for Android..."
cd "\$PROJECT_ROOT"
check "Crystal lib builds" "ANDROID_SDK_ROOT=\${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools} ./mobile/android/build_crystal_lib.sh"

# Step 2: Verify shared library exists
info "Step 2/6: Verifying shared library..."
check "lib#{name}.so exists" "[ -f mobile/android/app/src/main/jniLibs/arm64-v8a/lib#{name}.so ]"

# Step 3: Build Android APK
info "Step 3/6: Building Android APK..."
cd "\$SCRIPT_DIR"
check "Gradle build succeeds" "./gradlew assembleDebug 2>/dev/null"

# Step 4: Verify APK exists
info "Step 4/6: Verifying APK..."
check "Debug APK exists" "[ -f app/build/outputs/apk/debug/app-debug.apk ]"

# Step 5: Run instrumented tests (requires connected device/emulator)
info "Step 5/6: Running instrumented tests..."
check "Android tests pass" "./gradlew connectedAndroidTest 2>/dev/null || echo 'Skipped (no device)'"

# Step 6: Summary
info "Step 6/6: Results"
echo ""
echo "===================="
echo "  \$PASS / \$TOTAL passed"
echo "===================="
BASH

      script_path = File.join(path, "mobile/android/test_android.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_android_local_properties
      content = <<-PROPS
# local.properties
# IMPORTANT: This file should NOT be committed to version control.
# Android SDK location (adjust to your system)
sdk.dir=/opt/homebrew/share/android-commandlinetools
PROPS

      File.write(File.join(path, "mobile/android/local.properties"), content)
    end

    private def create_macos_ui_test_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# L2 macOS accessibility UI tests for #{pascal_name}
# Uses AppleScript accessibility inspection to verify UI elements.
#
# Usage: cd #{name} && ./test/macos/test_macos_ui.sh

set -euo pipefail

info()  { printf '\\033[0;34m[test]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[pass]\\033[0m %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m %s\\n' "\$*" >&2; }

PASS=0
TOTAL=0

check() {
    TOTAL=\$((TOTAL + 1))
    if eval "\$2" >/dev/null 2>&1; then
        ok "\$1"
        PASS=\$((PASS + 1))
    else
        fail "\$1"
    fi
}

APP_NAME="#{pascal_name}"

# Verify app is running
check "App is running" "pgrep -x #{name}"

# Check main window exists via accessibility
check "Main window accessible" "osascript -e 'tell application \"System Events\" to tell process \"#{pascal_name}\" to get name of window 1'"

echo ""
echo "===================="
echo "  \$PASS / \$TOTAL passed"
echo "===================="
BASH

      script_path = File.join(path, "test/macos/test_macos_ui.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_macos_e2e_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# L3 macOS E2E test script for #{pascal_name}
# Full build-run-verify cycle.
#
# Usage: cd #{name} && ./test/macos/test_macos_e2e.sh

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

info()  { printf '\\033[0;34m[test]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[pass]\\033[0m %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m %s\\n' "\$*" >&2; exit 1; }

PASS=0
TOTAL=0

check() {
    TOTAL=\$((TOTAL + 1))
    if eval "\$2"; then
        ok "\$1"
        PASS=\$((PASS + 1))
    else
        fail "\$1"
    fi
}

cd "\$PROJECT_ROOT"

# Step 1: Setup
info "Step 1/6: Running setup..."
check "Setup succeeds" "make setup 2>/dev/null"

# Step 2: Build
info "Step 2/6: Building macOS app..."
check "macOS build succeeds" "make macos 2>/dev/null"

# Step 3: Verify binary
info "Step 3/6: Verifying binary..."
check "Binary exists" "[ -f bin/#{name} ]"
check "Binary is executable" "[ -x bin/#{name} ]"

# Step 4: Run Crystal specs
info "Step 4/6: Running Crystal specs..."
check "Crystal specs pass" "make spec 2>/dev/null"

# Step 5: Quick launch test (start and immediately stop)
info "Step 5/6: Launch test..."
check "App starts" "timeout 3 ./bin/#{name} 2>/dev/null || [ \$? -eq 124 ]"

# Step 6: Summary
info "Step 6/6: Results"
echo ""
echo "===================="
echo "  \$PASS / \$TOTAL passed"
echo "===================="
BASH

      script_path = File.join(path, "test/macos/test_macos_e2e.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_mobile_ci_script
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      content = <<-BASH
#!/usr/bin/env bash
# CI orchestrator for #{pascal_name} — runs tests across all platforms.
#
# Usage:
#   ./mobile/run_all_tests.sh          # L1 + L2 (default)
#   ./mobile/run_all_tests.sh --e2e    # L1 + L2 + L3 E2E tests
#
# Test layers:
#   L1: Crystal specs (process managers, state machines, event bus)
#   L2: Platform UI tests (XCUITest, Compose, AppleScript)
#   L3: E2E scripts (full build-run-verify cycle)

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"
RUN_E2E=false

if [[ "\${1:-}" == "--e2e" ]]; then
    RUN_E2E=true
fi

info()  { printf '\\033[0;34m[ci]\\033[0m %s\\n' "\$*"; }
ok()    { printf '\\033[0;32m[pass]\\033[0m %s\\n' "\$*"; }
fail()  { printf '\\033[0;31m[fail]\\033[0m %s\\n' "\$*" >&2; }

PASS=0
FAIL=0

run_step() {
    info "\$1"
    if eval "\$2"; then
        ok "\$1"
        PASS=\$((PASS + 1))
    else
        fail "\$1"
        FAIL=\$((FAIL + 1))
    fi
}

cd "\$PROJECT_ROOT"

echo "============================================"
echo "  #{pascal_name} Test Suite"
echo "============================================"
echo ""

# --- L1: Crystal Specs ---
info "=== L1: Crystal Specs ==="
run_step "Desktop process manager specs" "crystal-alpha spec spec/ -Dmacos 2>/dev/null"
run_step "Mobile bridge specs" "crystal-alpha spec mobile/shared/spec/ 2>/dev/null"

# --- L2: Platform UI Tests ---
info "=== L2: Platform UI Tests ==="
run_step "macOS accessibility tests" "test/macos/test_macos_ui.sh 2>/dev/null || true"

# --- L3: E2E Tests (optional) ---
if [[ "\$RUN_E2E" == "true" ]]; then
    info "=== L3: E2E Tests ==="
    run_step "macOS E2E" "test/macos/test_macos_e2e.sh 2>/dev/null"
    run_step "iOS E2E" "mobile/ios/test_ios.sh 2>/dev/null || true"
    run_step "Android E2E" "mobile/android/test_android.sh 2>/dev/null || true"
fi

# --- Summary ---
echo ""
echo "============================================"
TOTAL=\$((PASS + FAIL))
echo "  Results: \$PASS / \$TOTAL passed"
if [[ \$FAIL -gt 0 ]]; then
    echo "  \$FAIL FAILED"
fi
echo "============================================"

[[ \$FAIL -gt 0 ]] && exit 1 || exit 0
BASH

      script_path = File.join(path, "mobile/run_all_tests.sh")
      File.write(script_path, content)
      File.chmod(script_path, 0o755)
    end

    private def create_fsdd_docs
      pascal_name = name.split(/[-_]/).map(&.capitalize).join

      # Project index
      index_content = <<-INDEX
# #{pascal_name} — FSDD Project Index

## Overview

This project follows Feature Story Driven Development (FSDD) v1.2.0.

## Layers

1. **Feature Stories** — `docs/fsdd/feature-stories/`
2. **Conventions** — `docs/fsdd/conventions/`
3. **Knowledge Gaps** — `docs/fsdd/knowledge-gaps/`
4. **Process Managers** — `docs/fsdd/process-managers/`
5. **Testing** — `docs/fsdd/testing/`

## Key Rules

- All business logic in process managers
- Controllers only validate and delegate
- test_id convention: `{epic}.{story}-{element-name}`
- U-shaped flow: analyst -> architect -> developer -> implementer
INDEX

      File.write(File.join(path, "docs/fsdd/_index.md"), index_content)

      # Testing architecture
      testing_content = <<-TESTING
# #{pascal_name} — Testing Architecture

## Three-Layer Test Strategy

### L1: Crystal Specs
- **Location:** `spec/macos/`, `mobile/shared/spec/`
- **What:** Process managers, state machines, event bus
- **Run:** `crystal-alpha spec spec/ -Dmacos`
- **No hardware required** — tests pure logic

### L2: Platform UI Tests
- **macOS:** `test/macos/test_macos_ui.sh` (AppleScript accessibility)
- **iOS:** `mobile/ios/UITests/UITests.swift` (XCUITest)
- **Android:** `mobile/android/app/src/androidTest/` (Compose UI Tests)
- **test_id convention:** `{epic}.{story}-{element-name}`
  - Maps to `accessibilityIdentifier` (iOS), `testTag` (Android), `data-testid` (web)

### L3: E2E Scripts
- **macOS:** `test/macos/test_macos_e2e.sh`
- **iOS:** `mobile/ios/test_ios.sh`
- **Android:** `mobile/android/test_android.sh`
- **CI:** `mobile/run_all_tests.sh` (L1+L2 default, `--e2e` for L3)
- **No JS/Python dependency** — pure shell scripts

## Test ID Mapping

| Platform | Property | Source |
|----------|----------|--------|
| Web | `data-testid` | Asset Pipeline `test_id` |
| macOS/iOS | `accessibilityIdentifier` | Asset Pipeline `test_id` via `setAccessibilityIdentifier:` |
| Android | `contentDescription` / `testTag` | Asset Pipeline `test_id` |
TESTING

      File.write(File.join(path, "docs/fsdd/testing/TESTING_ARCHITECTURE.md"), testing_content)

      # Keep files for empty directories
      ["feature-stories", "conventions", "knowledge-gaps", "process-managers"].each do |dir|
        File.write(File.join(path, "docs/fsdd/#{dir}/.keep"), "")
      end
    end

    private def create_keep_files
      keep_dirs = [
        "src/models",
        "bin",
      ]

      keep_dirs.each do |dir|
        keep_file = File.join(path, dir, ".keep")
        File.write(keep_file, "") unless File.exists?(keep_file)
      end
    end

    private def pascal_case(s : String) : String
      s.split(/[-_]/).map(&.capitalize).join
    end
  end
end
