require "../amber_cli_spec"
require "../../src/amber_cli/native/capability_manifest"

describe AmberCLI::Native::CapabilityManifest do
  describe ".default_for" do
    it "builds a validated manifest with Apple shell capabilities" do
      manifest = AmberCLI::Native::CapabilityManifest.default_for("my_app")

      manifest.apple.bundle_identifier.should eq("com.example.my.app")
      manifest.apple.minimum_ios_version.should eq("16.1")
      manifest.apple.windows.first.title.should eq("MyApp")
      manifest.apple.widgets.widgets.first.title.should eq("MyApp Status")
      manifest.apple.live_activities.activities.first.attributes_type.should eq("MyAppActivityAttributes")

      widget_scaffold = manifest.widgets_catalog("MyApp").export_widgetkit_scaffold
      widget_scaffold.should contain("enum MyAppWidgetKitScaffold")
      widget_scaffold.should contain("StaticConfiguration(kind: \"my-app-status\"")

      activity_scaffold = manifest.live_activities_catalog("MyApp").export_activitykit_scaffold
      activity_scaffold.should contain("public enum MyAppLiveActivities")
      activity_scaffold.should contain("public struct MyAppActivityAttributes: ActivityAttributes")

      shortcut_scaffold = manifest.shortcuts_catalog("MyApp").export_app_intents_scaffold
      shortcut_scaffold.should contain("enum MyAppAppIntentsScaffold")
      shortcut_scaffold.should contain("struct OpenMyAppIntent: AppIntent")

      notification_scaffold = manifest.notifications_catalog("MyApp").export_swift_scaffold
      notification_scaffold.should contain("public enum MyAppNotifications")
      notification_scaffold.should contain("UNUserNotificationCenter.current().setNotificationCategories(categories)")

      quick_actions = UI::HomeScreenQuickActions.export_plist_fragment(manifest.quick_actions_catalog)
      quick_actions.should contain("UIApplicationShortcutItemType")
      quick_actions.should contain("com.example.my.app.open")
    end
  end

  describe ".load" do
    it "round-trips the generated YAML and rejects duplicate widget identifiers" do
      SpecHelper.within_temp_directory do |temp_dir|
        manifest = AmberCLI::Native::CapabilityManifest.default_for("my_app")
        manifest_path = File.join(temp_dir, "native.yml")
        File.write(manifest_path, manifest.to_yaml_document)

        loaded = AmberCLI::Native::CapabilityManifest.load(manifest_path)
        loaded.apple.bundle_identifier.should eq("com.example.my.app")
        loaded.apple.shortcuts.shortcuts.first.identifier.should eq("open-my-app")

        loaded.apple.widgets.widgets << AmberCLI::Native::CapabilityManifest::WidgetSpec.new(
          title: "Another Status",
          identifier: "my-app-status"
        )

        expect_raises(ArgumentError, /duplicate widget identifiers/) do
          loaded.validate!
        end
      end
    end

    it "rejects live activities when minimum iOS is below 16.1" do
      manifest = AmberCLI::Native::CapabilityManifest.default_for("my_app")
      manifest.apple.minimum_ios_version = "16.0"

      expect_raises(ArgumentError, /at least 16\.1/) do
        manifest.validate!
      end
    end
  end
end
