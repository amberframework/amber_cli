require "../amber_cli_spec"
require "../../src/amber_cli/generators/native_app"

describe AmberCLI::Generators::NativeApp do
  describe "#generate" do
    it "creates the full native app project structure" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "test_native_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "test_native_app")
        generator.generate

        # Verify top-level files exist
        File.exists?(File.join(project_path, "shard.yml")).should be_true
        File.exists?(File.join(project_path, ".amber.yml")).should be_true
        File.exists?(File.join(project_path, ".gitignore")).should be_true
        File.exists?(File.join(project_path, "Makefile")).should be_true
        File.exists?(File.join(project_path, "CLAUDE.md")).should be_true
      end
    end

    it "creates shard.yml with correct dependencies" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        shard_content = File.read(File.join(project_path, "shard.yml"))

        # Must have amber (patterns only)
        shard_content.should contain("amber:")
        shard_content.should contain("crimson-knight/amber")

        # Must have asset_pipeline with cross-platform branch
        shard_content.should contain("asset_pipeline:")
        shard_content.should contain("feature/utility-first-css-asset-pipeline")

        # Must have crystal-audio
        shard_content.should contain("crystal-audio:")

        # Must have correct project name
        shard_content.should contain("name: my_app")
        shard_content.should contain("main: src/my_app.cr")
      end
    end

    it "creates amber.yml with type: native" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        amber_content = File.read(File.join(project_path, ".amber.yml"))
        amber_content.should contain("type: native")
        amber_content.should contain("app: my_app")
      end
    end

    it "creates main file WITHOUT HTTP server" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        main_content = File.read(File.join(project_path, "src/my_app.cr"))

        # MUST use Amber.settings directly
        main_content.should contain("Amber.settings.name")

        # MUST NOT start an HTTP server
        main_content.should_not contain("Amber::Server.start")

        # Comments warn about Server.configure but it must not appear as actual code.
        # Filter out comment lines and check no code line invokes it.
        code_lines = main_content.lines.reject { |l| l.strip.starts_with?("#") }
        code_lines.none? { |l| l.includes?("Amber::Server.configure") }.should be_true

        # MUST require asset_pipeline/ui (not just "ui")
        main_content.should contain("require \"asset_pipeline/ui\"")
      end
    end

    it "creates config without HTTP server" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        config_content = File.read(File.join(project_path, "config/application.cr"))
        config_content.should contain("Amber.settings.name")

        # Comments warn about Server.configure but it must not appear as actual code.
        code_lines = config_content.lines.reject { |l| l.strip.starts_with?("#") }
        code_lines.none? { |l| l.includes?("Amber::Server.configure") }.should be_true
      end
    end

    it "creates Makefile with correct platform flags" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        makefile_content = File.read(File.join(project_path, "Makefile"))

        # CRITICAL: -Dmacos flag must be present
        makefile_content.should contain("-Dmacos")

        # Must have crystal-alpha compiler
        makefile_content.should contain("crystal-alpha")

        # Must have -fno-objc-arc for ObjC bridge
        makefile_content.should contain("-fno-objc-arc")

        # Must have framework link flags
        makefile_content.should contain("-framework AppKit")
        makefile_content.should contain("-framework Foundation")
        makefile_content.should contain("-framework AVFoundation")
        makefile_content.should contain("-lobjc")

        # Must have crystal-audio symlink in setup
        makefile_content.should contain("ln -sf crystal-audio lib/crystal_audio")

        # Must have build targets
        makefile_content.should contain("macos:")
        makefile_content.should contain("macos-release:")
        makefile_content.should contain("setup:")
        makefile_content.should contain("spec:")
      end
    end

    it "creates FSDD process manager structure" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        # Process manager exists
        File.exists?(File.join(project_path, "src/process_managers/main_process_manager.cr")).should be_true

        pm_content = File.read(File.join(project_path, "src/process_managers/main_process_manager.cr"))
        pm_content.should contain("module ProcessManagers")
        pm_content.should contain("class MainProcessManager")

        # Controller delegates to process manager
        ctrl_content = File.read(File.join(project_path, "src/controllers/main_controller.cr"))
        ctrl_content.should contain("@process_manager")
        ctrl_content.should contain("ProcessManagers::MainProcessManager")
      end
    end

    it "creates event bus" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        File.exists?(File.join(project_path, "src/events/event_bus.cr")).should be_true
        content = File.read(File.join(project_path, "src/events/event_bus.cr"))
        content.should contain("module Events")
        content.should contain("class EventBus")
      end
    end

    it "creates ObjC platform bridge with GCD helpers" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        bridge_path = File.join(project_path, "src/platform/my_app_platform_bridge.m")
        File.exists?(bridge_path).should be_true

        bridge_content = File.read(bridge_path)
        # Must have GCD dispatch helpers (never use Crystal spawn in NSApp)
        bridge_content.should contain("dispatch_to_main")
        bridge_content.should contain("dispatch_to_background")
        bridge_content.should contain("dispatch_async")

        # Must document the alias vs type rule for C function pointers
        bridge_content.should contain("alias")
      end
    end

    it "creates L1 Crystal specs" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        # Desktop specs
        File.exists?(File.join(project_path, "spec/spec_helper.cr")).should be_true
        File.exists?(File.join(project_path, "spec/macos/process_manager_spec.cr")).should be_true

        # Mobile bridge specs
        File.exists?(File.join(project_path, "mobile/shared/spec/bridge_spec.cr")).should be_true

        spec_content = File.read(File.join(project_path, "spec/macos/process_manager_spec.cr"))
        spec_content.should contain("ProcessManagers::MainProcessManager")
      end
    end

    it "creates mobile shared bridge with state machine" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        bridge_path = File.join(project_path, "mobile/shared/bridge.cr")
        File.exists?(bridge_path).should be_true

        content = File.read(bridge_path)
        content.should contain("enum AppState")
        content.should contain("class Bridge")
        content.should contain("transition_to")
      end
    end

    it "creates iOS build script with _main fix and correct flags" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        script_path = File.join(project_path, "mobile/ios/build_crystal_lib.sh")
        File.exists?(script_path).should be_true

        content = File.read(script_path)
        # CRITICAL: Must fix _main symbol conflict for iOS
        content.should contain("unexported_symbol _main")
        content.should contain("-Dios")
        content.should contain("crystal-alpha")

        # Must be executable
        File.info(script_path).permissions.owner_execute?.should be_true
      end
    end

    it "creates iOS project.yml with correct exclusions" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        content = File.read(File.join(project_path, "mobile/ios/project.yml"))
        # CRITICAL: Crystal only compiles arm64 — must exclude x86_64
        content.should contain("EXCLUDED_ARCHS")
        content.should contain("x86_64")
      end
    end

    it "creates Android build script with -laaudio flag" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        script_path = File.join(project_path, "mobile/android/build_crystal_lib.sh")
        File.exists?(script_path).should be_true

        content = File.read(script_path)
        # CRITICAL: -laaudio is required for Android audio
        content.should contain("-laaudio")
        content.should contain("-llog")
        content.should contain("-landroid")
        content.should contain("-Dandroid")
        content.should contain("GC_BUILTIN_ATOMIC")
        content.should contain("crystal-alpha")

        # Must be executable
        File.info(script_path).permissions.owner_execute?.should be_true
      end
    end

    it "creates Android build.gradle.kts with JDK 17 and Compose" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        content = File.read(File.join(project_path, "mobile/android/build.gradle.kts"))
        content.should contain("VERSION_17")
        content.should contain("compose")
        content.should contain("material-icons-extended")
        content.should contain("arm64-v8a")
      end
    end

    it "creates iOS UI test template with test_id convention" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        content = File.read(File.join(project_path, "mobile/ios/UITests/UITests.swift"))
        content.should contain("XCTestCase")
        content.should contain("accessibilityIdentifier")
        content.should contain("{epic}.{story}-{element-name}")
      end
    end

    it "creates Android UI test template with testTag convention" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        content = File.read(File.join(project_path, "mobile/android/app/src/androidTest/java/com/my_app/app/MyAppUITests.kt"))
        content.should contain("onNodeWithTag")
        content.should contain("{epic}.{story}-{element-name}")
      end
    end

    it "creates L3 E2E test scripts" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        # iOS E2E
        ios_script = File.join(project_path, "mobile/ios/test_ios.sh")
        File.exists?(ios_script).should be_true
        File.info(ios_script).permissions.owner_execute?.should be_true

        # Android E2E
        android_script = File.join(project_path, "mobile/android/test_android.sh")
        File.exists?(android_script).should be_true
        File.info(android_script).permissions.owner_execute?.should be_true

        # macOS E2E
        macos_e2e = File.join(project_path, "test/macos/test_macos_e2e.sh")
        File.exists?(macos_e2e).should be_true
        File.info(macos_e2e).permissions.owner_execute?.should be_true

        # macOS UI tests
        macos_ui = File.join(project_path, "test/macos/test_macos_ui.sh")
        File.exists?(macos_ui).should be_true
        File.info(macos_ui).permissions.owner_execute?.should be_true
      end
    end

    it "creates CI orchestrator script" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        ci_script = File.join(project_path, "mobile/run_all_tests.sh")
        File.exists?(ci_script).should be_true
        File.info(ci_script).permissions.owner_execute?.should be_true

        content = File.read(ci_script)
        content.should contain("--e2e")
        content.should contain("L1")
        content.should contain("L2")
        content.should contain("L3")
      end
    end

    it "creates FSDD documentation structure" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        File.exists?(File.join(project_path, "docs/fsdd/_index.md")).should be_true
        File.exists?(File.join(project_path, "docs/fsdd/testing/TESTING_ARCHITECTURE.md")).should be_true

        testing_content = File.read(File.join(project_path, "docs/fsdd/testing/TESTING_ARCHITECTURE.md"))
        testing_content.should contain("Three-Layer Test Strategy")
        testing_content.should contain("L1: Crystal Specs")
        testing_content.should contain("L2: Platform UI Tests")
        testing_content.should contain("L3: E2E Scripts")
        testing_content.should contain("test_id")
      end
    end

    it "uses correct pascal case for project names with underscores" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_cool_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_cool_app")
        generator.generate

        main_content = File.read(File.join(project_path, "src/my_cool_app.cr"))
        main_content.should contain("MyCoolApp")
      end
    end

    it "uses correct pascal case for project names with hyphens" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my-cool-app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my-cool-app")
        generator.generate

        main_content = File.read(File.join(project_path, "src/my-cool-app.cr"))
        main_content.should contain("MyCoolApp")
      end
    end

    it "does not create web-specific directories" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        # Native apps should NOT have these web-specific directories
        Dir.exists?(File.join(project_path, "public")).should be_false
        Dir.exists?(File.join(project_path, "src/views")).should be_false
        Dir.exists?(File.join(project_path, "src/channels")).should be_false
        Dir.exists?(File.join(project_path, "src/sockets")).should be_false
        Dir.exists?(File.join(project_path, "src/mailers")).should be_false
        Dir.exists?(File.join(project_path, "src/jobs")).should be_false
        Dir.exists?(File.join(project_path, "db")).should be_false
      end
    end

    it "creates the correct directory structure" do
      SpecHelper.within_temp_directory do |temp_dir|
        project_path = File.join(temp_dir, "my_app")
        generator = AmberCLI::Generators::NativeApp.new(project_path, "my_app")
        generator.generate

        # Native app directories
        Dir.exists?(File.join(project_path, "src/controllers")).should be_true
        Dir.exists?(File.join(project_path, "src/models")).should be_true
        Dir.exists?(File.join(project_path, "src/process_managers")).should be_true
        Dir.exists?(File.join(project_path, "src/ui")).should be_true
        Dir.exists?(File.join(project_path, "src/platform")).should be_true
        Dir.exists?(File.join(project_path, "src/events")).should be_true
        Dir.exists?(File.join(project_path, "spec/macos")).should be_true
        Dir.exists?(File.join(project_path, "mobile/shared")).should be_true
        Dir.exists?(File.join(project_path, "mobile/ios")).should be_true
        Dir.exists?(File.join(project_path, "mobile/android")).should be_true
        Dir.exists?(File.join(project_path, "test/macos")).should be_true
        Dir.exists?(File.join(project_path, "docs/fsdd")).should be_true
      end
    end
  end
end
