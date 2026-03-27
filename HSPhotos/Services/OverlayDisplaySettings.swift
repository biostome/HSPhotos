import Foundation

extension Notification.Name {
    static let overlayDisplaySettingsDidChange = Notification.Name("overlayDisplaySettingsDidChange")
}

final class OverlayDisplaySettings {
    static let shared = OverlayDisplaySettings()

    private enum Key {
        static let overlayEnabled = "overlay_display_enabled"
        static let showCreationDateInCustom = "overlay_show_creation_in_custom"
        static let showModificationDateInCustom = "overlay_show_modification_in_custom"
        static let showCustomOrderInDateSort = "overlay_show_custom_order_in_date_sort"
        static let showFieldPrefixes = "overlay_show_field_prefixes"
    }

    private let defaults = UserDefaults.standard

    var overlayEnabled: Bool {
        didSet { saveAndNotify(key: Key.overlayEnabled, value: overlayEnabled) }
    }

    var showCreationDateInCustom: Bool {
        didSet { saveAndNotify(key: Key.showCreationDateInCustom, value: showCreationDateInCustom) }
    }

    var showModificationDateInCustom: Bool {
        didSet { saveAndNotify(key: Key.showModificationDateInCustom, value: showModificationDateInCustom) }
    }

    var showCustomOrderInDateSort: Bool {
        didSet { saveAndNotify(key: Key.showCustomOrderInDateSort, value: showCustomOrderInDateSort) }
    }

    var showFieldPrefixes: Bool {
        didSet { saveAndNotify(key: Key.showFieldPrefixes, value: showFieldPrefixes) }
    }

    private init() {
        overlayEnabled = defaults.object(forKey: Key.overlayEnabled) as? Bool ?? true
        showCreationDateInCustom = defaults.object(forKey: Key.showCreationDateInCustom) as? Bool ?? true
        showModificationDateInCustom = defaults.object(forKey: Key.showModificationDateInCustom) as? Bool ?? true
        showCustomOrderInDateSort = defaults.object(forKey: Key.showCustomOrderInDateSort) as? Bool ?? true
        showFieldPrefixes = defaults.object(forKey: Key.showFieldPrefixes) as? Bool ?? true
    }

    private func saveAndNotify(key: String, value: Bool) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .overlayDisplaySettingsDidChange, object: nil)
    }
}
