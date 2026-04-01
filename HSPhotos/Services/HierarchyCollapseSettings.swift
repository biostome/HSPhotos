import Foundation

extension Notification.Name {
    static let hierarchyCollapseSettingsDidChange = Notification.Name("hierarchyCollapseSettingsDidChange")
}

/// 层级折叠时，中间「无编号」照片的语义
enum HierarchyCollapseSpanMode: Int, CaseIterable {
    /// 遇到无层级照片即断开折叠链（与历史行为一致）
    case breakAtUnnumbered = 0
    /// 折叠时把折叠根到下一同级/更浅有编号节点之间的无编号图一并隐藏
    case includeGaps = 1
}

final class HierarchyCollapseSettings {
    static let shared = HierarchyCollapseSettings()

    private enum Key {
        static let spanMode = "hierarchy_collapse_span_mode"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var spanMode: HierarchyCollapseSpanMode {
        get {
            let raw = defaults.integer(forKey: Key.spanMode)
            return HierarchyCollapseSpanMode(rawValue: raw) ?? .breakAtUnnumbered
        }
        set {
            guard newValue != spanMode else { return }
            defaults.set(newValue.rawValue, forKey: Key.spanMode)
            NotificationCenter.default.post(name: .hierarchyCollapseSettingsDidChange, object: nil)
        }
    }
}
