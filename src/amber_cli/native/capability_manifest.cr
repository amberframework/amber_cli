require "set"
require "yaml"
require "asset_pipeline/ui"
require "./naming"

module AmberCLI::Native
  class CapabilityManifest
    include YAML::Serializable
    include YAML::Serializable::Strict

    property schema_version : Int32 = 1
    property apple : AppleCapabilities = AppleCapabilities.new

    def initialize(@schema_version : Int32 = 1, @apple : AppleCapabilities = AppleCapabilities.new)
    end

    def self.default_for(app_name : String) : self
      pascal_name = Naming.pascalize(app_name)
      slug = Naming.slugify(app_name, "native-app")
      bundle_identifier = "com.example.#{Naming.bundle_identifier_segment(app_name)}"

      manifest = new
      manifest.apple.bundle_identifier = bundle_identifier
      manifest.apple.minimum_ios_version = "16.1"
      manifest.apple.windows << WindowSpec.new(
        identifier: "main",
        title: pascal_name,
        default_size: [1200, 820] of Int32
      )
      manifest.apple.notifications.categories << NotificationCategorySpec.new(
        identifier: "general-updates",
        actions: [
          NotificationActionSpec.new(
            identifier: "open-app",
            title: "Open #{pascal_name}",
            kind: "default",
            options: ["foreground"] of String
          ),
        ] of NotificationActionSpec,
        options: ["custom_dismiss_action"] of String
      )
      manifest.apple.shortcuts.shortcuts << AppShortcutSpec.new(
        title: "Open #{pascal_name}",
        identifier: "open-#{slug}",
        subtitle: "Bring #{pascal_name} to the foreground",
        summary: "Opens the main #{pascal_name} workspace",
        icon: "app",
        phrases: ["Open #{pascal_name}", "Show #{pascal_name}"] of String
      )
      manifest.apple.quick_actions.actions << QuickActionSpec.new(
        type: "#{bundle_identifier}.open",
        title: "Open #{pascal_name}",
        subtitle: "Jump back into the app",
        system_image: "app"
      )
      manifest.apple.widgets.widgets << WidgetSpec.new(
        title: "#{pascal_name} Status",
        identifier: "#{slug}-status",
        summary: "Shows the latest #{pascal_name} state",
        placements: [
          WidgetPlacementSpec.new(
            surface: "home_screen",
            families: ["systemSmall", "systemMedium"] of String,
            timeline_intent: "snapshot",
            refresh_policy: "after:15m"
          ),
        ] of WidgetPlacementSpec
      )
      manifest.apple.live_activities.activities << LiveActivitySpec.new(
        attributes_type: "#{pascal_name}ActivityAttributes",
        identifier: "#{slug}-live-activity",
        attributes: {"phase" => "idle"} of String => String,
        content_state: {"status" => "ready"} of String => String,
        update_intent: LiveActivityUpdateIntentSpec.new(
          identifier: "open-#{slug}",
          title: "Open #{pascal_name}",
          subtitle: "Resume your current flow",
          system_image: "app"
        )
      )
      manifest.validate!
    end

    def self.load(path : String) : self
      manifest = from_yaml(File.read(path))
      manifest.validate!
    rescue ex : YAML::ParseException
      raise ArgumentError.new("Unable to parse native capability manifest at #{path}: #{ex.message}")
    end

    def validate! : self
      raise ArgumentError.new("native capability manifest schema_version must be 1") unless @schema_version == 1
      @apple.validate!
      self
    end

    def to_yaml_document : String
      validate!
      String.build do |io|
        io << "# Native capability manifest for Amber native applications.\n"
        io << "# Edit this file to declare Apple shell surfaces.\n"
        io << "# Amber CLI owns mobile/apple/generated/**/*; keep hand edits in mobile/ios/Sources/**/*.\n\n"
        io << to_yaml
      end
    end

    def widgets_catalog(application_name : String) : UI::Widgets
      catalog = UI::Widgets.new(application_name, bundle_identifier: apple.bundle_identifier)

      apple.widgets.widgets.each do |entry|
        widget = catalog.add_widget(
          entry.title,
          identifier: blank_to_nil(entry.identifier),
          summary: entry.summary,
          is_enabled: entry.is_enabled
        )

        entry.placements.each do |placement|
          widget.add_placement(
            placement.surface,
            families: placement.families,
            timeline_intent: placement.timeline_intent,
            refresh_policy: placement.refresh_policy,
            notes: placement.notes
          )
        end
      end

      catalog
    end

    def live_activities_catalog(application_name : String) : UI::LiveActivities
      catalog = UI::LiveActivities.new(application_name, bundle_identifier: apple.bundle_identifier)

      apple.live_activities.activities.each do |entry|
        activity = catalog.add_activity(
          entry.attributes_type,
          identifier: blank_to_nil(entry.identifier),
          attributes: entry.attributes,
          content_state: entry.content_state,
          is_active: entry.is_active
        )

        if update_intent = entry.update_intent
          activity.build_update_intent(
            update_intent.identifier,
            title: update_intent.title,
            subtitle: update_intent.subtitle,
            system_image: update_intent.system_image,
            user_info: update_intent.user_info,
            is_enabled: update_intent.is_enabled
          )
        end
      end

      catalog
    end

    def shortcuts_catalog(application_name : String) : UI::AppShortcuts
      catalog = UI::AppShortcuts.new(application_name, bundle_identifier: apple.bundle_identifier)

      apple.shortcuts.shortcuts.each do |entry|
        shortcut = catalog.add_shortcut(
          entry.title,
          identifier: blank_to_nil(entry.identifier),
          subtitle: entry.subtitle,
          summary: entry.summary,
          icon: entry.icon,
          phrases: entry.phrases,
          is_enabled: entry.is_enabled,
          is_discoverable: entry.is_discoverable
        )

        entry.parameters.each do |parameter|
          shortcut.add_parameter(
            parameter.name,
            prompt: parameter.prompt,
            type: parameter.type,
            default_value: parameter.default_value,
            is_required: parameter.is_required
          )
        end
      end

      catalog
    end

    def notifications_catalog(application_name : String) : UI::NotificationsCatalog
      catalog = UI::NotificationsCatalog.new(application_name, bundle_identifier: apple.bundle_identifier)

      apple.notifications.categories.each do |entry|
        category = UI::NotificationCategory.new(
          entry.identifier,
          intent_identifiers: entry.intent_identifiers,
          options: entry.options,
          is_enabled: entry.is_enabled
        )

        entry.actions.each do |action|
          category.add_action(
            action.identifier,
            action.title,
            kind: action.kind,
            options: action.options,
            text_input_button_title: action.text_input_button_title,
            text_input_placeholder: action.text_input_placeholder,
            is_enabled: action.is_enabled
          )
        end

        catalog.add_category(category)
      end

      catalog
    end

    def quick_actions_catalog : UI::QuickActionsCatalog
      catalog = UI::QuickActionsCatalog.new

      apple.quick_actions.actions.each do |entry|
        catalog.add_action(
          type: entry.type,
          title: entry.title,
          subtitle: entry.subtitle,
          system_image: entry.system_image,
          user_info: entry.user_info
        )
      end

      catalog
    end

    private def blank_to_nil(value : String) : String?
      stripped = value.strip
      stripped.empty? ? nil : stripped
    end

    class AppleCapabilities
      include YAML::Serializable
      include YAML::Serializable::Strict

      property bundle_identifier : String = ""
      property minimum_ios_version : String = "16.1"
      property windows : Array(WindowSpec) = [] of WindowSpec
      property menu_bar : ToggleCapability = ToggleCapability.new
      property status_bar : ToggleCapability = ToggleCapability.new
      property notifications : NotificationsCapability = NotificationsCapability.new
      property shortcuts : ShortcutsCapability = ShortcutsCapability.new
      property quick_actions : QuickActionsCapability = QuickActionsCapability.new
      property widgets : WidgetsCapability = WidgetsCapability.new
      property live_activities : LiveActivitiesCapability = LiveActivitiesCapability.new

      def initialize(
        @bundle_identifier : String = "",
        @minimum_ios_version : String = "16.1",
        @windows : Array(WindowSpec) = [] of WindowSpec,
        @menu_bar : ToggleCapability = ToggleCapability.new,
        @status_bar : ToggleCapability = ToggleCapability.new,
        @notifications : NotificationsCapability = NotificationsCapability.new,
        @shortcuts : ShortcutsCapability = ShortcutsCapability.new,
        @quick_actions : QuickActionsCapability = QuickActionsCapability.new,
        @widgets : WidgetsCapability = WidgetsCapability.new,
        @live_activities : LiveActivitiesCapability = LiveActivitiesCapability.new
      )
      end

      def validate! : self
        raise ArgumentError.new("apple.bundle_identifier cannot be blank") if @bundle_identifier.strip.empty?
        raise ArgumentError.new("apple.minimum_ios_version cannot be blank") if @minimum_ios_version.strip.empty?
        minimum_ios_version_tuple = parse_ios_version(@minimum_ios_version)

        @windows.each(&.validate!)
        @notifications.validate!
        @shortcuts.validate!
        @quick_actions.validate!
        @widgets.validate!
        @live_activities.validate!

        if @live_activities.enabled && minimum_ios_version_tuple < {16, 1}
          raise ArgumentError.new("apple.minimum_ios_version must be at least 16.1 when live activities are enabled")
        end

        ensure_unique(@windows.map(&.identifier), "apple.windows identifiers")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end

      private def parse_ios_version(value : String) : Tuple(Int32, Int32)
        match = /^(\d+)(?:\.(\d+))?(?:\.\d+)?$/.match(value.strip)
        raise ArgumentError.new("apple.minimum_ios_version must be a numeric iOS version like 16.1") unless match

        major = match[1].to_i
        minor = match[2]?.try(&.to_i) || 0
        {major, minor}
      end
    end

    class ToggleCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = false

      def initialize(@enabled : Bool = false)
      end
    end

    class WindowSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property identifier : String = "main"
      property title : String = "Main"
      property default_size : Array(Int32) = [1200, 820] of Int32

      def initialize(@identifier : String = "main", @title : String = "Main", @default_size : Array(Int32) = [1200, 820] of Int32)
      end

      def validate! : self
        raise ArgumentError.new("window identifier cannot be blank") if @identifier.strip.empty?
        raise ArgumentError.new("window title cannot be blank") if @title.strip.empty?
        raise ArgumentError.new("window default_size must contain width and height") unless @default_size.size == 2
        raise ArgumentError.new("window width must be positive") unless @default_size[0] > 0
        raise ArgumentError.new("window height must be positive") unless @default_size[1] > 0
        self
      end
    end

    class NotificationsCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true
      property categories : Array(NotificationCategorySpec) = [] of NotificationCategorySpec

      def initialize(@enabled : Bool = true, @categories : Array(NotificationCategorySpec) = [] of NotificationCategorySpec)
      end

      def validate! : self
        @categories.each(&.validate!)
        ensure_unique(@categories.map(&.identifier), "notification category identifiers")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class NotificationCategorySpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property identifier : String = ""
      property actions : Array(NotificationActionSpec) = [] of NotificationActionSpec
      property intent_identifiers : Array(String) = [] of String
      property options : Array(String) = [] of String
      property is_enabled : Bool = true

      def initialize(
        @identifier : String = "",
        @actions : Array(NotificationActionSpec) = [] of NotificationActionSpec,
        @intent_identifiers : Array(String) = [] of String,
        @options : Array(String) = [] of String,
        @is_enabled : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("notification category identifier cannot be blank") if @identifier.strip.empty?
        @actions.each(&.validate!)
        ensure_unique(@actions.map(&.identifier), "notification action identifiers for #{@identifier}")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class NotificationActionSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property identifier : String = ""
      property title : String = ""
      property kind : String = "default"
      property options : Array(String) = [] of String
      property text_input_button_title : String? = nil
      property text_input_placeholder : String? = nil
      property is_enabled : Bool = true

      def initialize(
        @identifier : String = "",
        @title : String = "",
        @kind : String = "default",
        @options : Array(String) = [] of String,
        @text_input_button_title : String? = nil,
        @text_input_placeholder : String? = nil,
        @is_enabled : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("notification action identifier cannot be blank") if @identifier.strip.empty?
        raise ArgumentError.new("notification action title cannot be blank") if @title.strip.empty?
        self
      end
    end

    class ShortcutsCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true
      property shortcuts : Array(AppShortcutSpec) = [] of AppShortcutSpec

      def initialize(@enabled : Bool = true, @shortcuts : Array(AppShortcutSpec) = [] of AppShortcutSpec)
      end

      def validate! : self
        @shortcuts.each(&.validate!)
        ensure_unique(@shortcuts.map(&.resolved_identifier), "app shortcut identifiers")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class AppShortcutSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property title : String = ""
      property identifier : String = ""
      property subtitle : String? = nil
      property summary : String? = nil
      property icon : String? = nil
      property phrases : Array(String) = [] of String
      property parameters : Array(AppShortcutParameterSpec) = [] of AppShortcutParameterSpec
      property is_enabled : Bool = true
      property is_discoverable : Bool = true

      def initialize(
        @title : String = "",
        @identifier : String = "",
        @subtitle : String? = nil,
        @summary : String? = nil,
        @icon : String? = nil,
        @phrases : Array(String) = [] of String,
        @parameters : Array(AppShortcutParameterSpec) = [] of AppShortcutParameterSpec,
        @is_enabled : Bool = true,
        @is_discoverable : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("app shortcut title cannot be blank") if @title.strip.empty?
        @parameters.each(&.validate!)
        self
      end

      def resolved_identifier : String
        return @identifier unless @identifier.strip.empty?
        Naming.slugify(@title, "shortcut")
      end
    end

    class AppShortcutParameterSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property name : String = ""
      property prompt : String? = nil
      property type : String? = nil
      property default_value : String? = nil
      property is_required : Bool = true

      def initialize(
        @name : String = "",
        @prompt : String? = nil,
        @type : String? = nil,
        @default_value : String? = nil,
        @is_required : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("app shortcut parameter name cannot be blank") if @name.strip.empty?
        self
      end
    end

    class QuickActionsCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true
      property actions : Array(QuickActionSpec) = [] of QuickActionSpec

      def initialize(@enabled : Bool = true, @actions : Array(QuickActionSpec) = [] of QuickActionSpec)
      end

      def validate! : self
        @actions.each(&.validate!)
        ensure_unique(@actions.map(&.type), "quick action types")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class QuickActionSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property type : String = ""
      property title : String = ""
      property subtitle : String? = nil
      property system_image : String? = nil
      property user_info : Hash(String, String) = {} of String => String

      def initialize(
        @type : String = "",
        @title : String = "",
        @subtitle : String? = nil,
        @system_image : String? = nil,
        @user_info : Hash(String, String) = {} of String => String
      )
      end

      def validate! : self
        raise ArgumentError.new("quick action type cannot be blank") if @type.strip.empty?
        raise ArgumentError.new("quick action title cannot be blank") if @title.strip.empty?
        self
      end
    end

    class WidgetsCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true
      property widgets : Array(WidgetSpec) = [] of WidgetSpec

      def initialize(@enabled : Bool = true, @widgets : Array(WidgetSpec) = [] of WidgetSpec)
      end

      def validate! : self
        @widgets.each(&.validate!)
        ensure_unique(@widgets.map(&.resolved_identifier), "widget identifiers")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class WidgetSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property title : String = ""
      property identifier : String = ""
      property summary : String? = nil
      property placements : Array(WidgetPlacementSpec) = [] of WidgetPlacementSpec
      property is_enabled : Bool = true

      def initialize(
        @title : String = "",
        @identifier : String = "",
        @summary : String? = nil,
        @placements : Array(WidgetPlacementSpec) = [] of WidgetPlacementSpec,
        @is_enabled : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("widget title cannot be blank") if @title.strip.empty?
        @placements.each(&.validate!)
        self
      end

      def resolved_identifier : String
        return @identifier unless @identifier.strip.empty?
        Naming.slugify(@title, "widget")
      end
    end

    class WidgetPlacementSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property surface : String = ""
      property families : Array(String) = [] of String
      property timeline_intent : String = "snapshot"
      property refresh_policy : String? = nil
      property notes : String? = nil

      def initialize(
        @surface : String = "",
        @families : Array(String) = [] of String,
        @timeline_intent : String = "snapshot",
        @refresh_policy : String? = nil,
        @notes : String? = nil
      )
      end

      def validate! : self
        raise ArgumentError.new("widget placement surface cannot be blank") if @surface.strip.empty?
        raise ArgumentError.new("widget timeline_intent cannot be blank") if @timeline_intent.strip.empty?
        self
      end
    end

    class LiveActivitiesCapability
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true
      property activities : Array(LiveActivitySpec) = [] of LiveActivitySpec

      def initialize(@enabled : Bool = true, @activities : Array(LiveActivitySpec) = [] of LiveActivitySpec)
      end

      def validate! : self
        @activities.each(&.validate!)
        ensure_unique(@activities.map(&.resolved_identifier), "live activity identifiers")
        self
      end

      private def ensure_unique(values : Array(String), label : String) : Nil
        seen = Set(String).new
        values.each do |value|
          raise ArgumentError.new("duplicate #{label}: #{value}") if seen.includes?(value)
          seen << value
        end
      end
    end

    class LiveActivitySpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property attributes_type : String = ""
      property identifier : String = ""
      property attributes : Hash(String, String) = {} of String => String
      property content_state : Hash(String, String) = {} of String => String
      property update_intent : LiveActivityUpdateIntentSpec? = nil
      property is_active : Bool = true

      def initialize(
        @attributes_type : String = "",
        @identifier : String = "",
        @attributes : Hash(String, String) = {} of String => String,
        @content_state : Hash(String, String) = {} of String => String,
        @update_intent : LiveActivityUpdateIntentSpec? = nil,
        @is_active : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("live activity attributes_type cannot be blank") if @attributes_type.strip.empty?
        @update_intent.try(&.validate!)
        self
      end

      def resolved_identifier : String
        return @identifier unless @identifier.strip.empty?
        Naming.slugify(@attributes_type, "live-activity")
      end
    end

    class LiveActivityUpdateIntentSpec
      include YAML::Serializable
      include YAML::Serializable::Strict

      property identifier : String = ""
      property title : String? = nil
      property subtitle : String? = nil
      property system_image : String? = nil
      property user_info : Hash(String, String) = {} of String => String
      property is_enabled : Bool = true

      def initialize(
        @identifier : String = "",
        @title : String? = nil,
        @subtitle : String? = nil,
        @system_image : String? = nil,
        @user_info : Hash(String, String) = {} of String => String,
        @is_enabled : Bool = true
      )
      end

      def validate! : self
        raise ArgumentError.new("live activity update intent identifier cannot be blank") if @identifier.strip.empty?
        self
      end
    end
  end
end
