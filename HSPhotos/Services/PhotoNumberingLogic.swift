//
//  PhotoNumberingLogic.swift
//  HSPhotos
//
//  多级编号、折叠可见性、后代判断的纯函数实现（assetID 级别），供 PhotoNumberingService 与单元测试共用。
//

import Foundation

enum PhotoNumberingLogic {

    // MARK: - 编号计算

    /// 根据顺序与层级计算编号，返回 assetID -> "1.2.3"
    static func computeNumbers(orderedAssetIDs: [String], levels: [String: Int]) -> [String: String] {
        var result: [String: String] = [:]
        var counters: [Int] = [0]
        var lastLevel = 0

        for id in orderedAssetIDs {
            let lv = levels[id] ?? 0
            guard lv > 0 else { continue }

            let correctedLv = min(lv, lastLevel + 1)

            while counters.count <= correctedLv {
                counters.append(0)
            }

            if correctedLv <= lastLevel {
                for i in (correctedLv + 1)..<counters.count {
                    counters[i] = 0
                }
            }

            counters[correctedLv] += 1
            lastLevel = correctedLv

            let parts = (1...correctedLv).map { String(counters[$0]) }
            result[id] = parts.joined(separator: ".")
        }
        return result
    }

    // MARK: - 后代判断

    static func hasDescendants(
        assetID: String,
        orderedAssetIDs: [String],
        levels: [String: Int],
        spanMode: HierarchyCollapseSpanMode
    ) -> Bool {
        let myLevel = levels[assetID] ?? 0
        guard myLevel > 0 else { return false }
        guard let idx = orderedAssetIDs.firstIndex(of: assetID) else { return false }

        if spanMode == .breakAtUnnumbered {
            for i in (idx + 1)..<orderedAssetIDs.count {
                let lv = levels[orderedAssetIDs[i]] ?? 0
                if lv == 0 { return false }
                if lv <= myLevel { return false }
                if lv > myLevel { return true }
            }
            return false
        }

        var i = idx + 1
        var foundHideable = false
        while i < orderedAssetIDs.count {
            let lv = levels[orderedAssetIDs[i]] ?? 0
            if lv > 0 && lv <= myLevel { break }
            if lv > myLevel {
                foundHideable = true
            } else if lv == 0,
                      let nextLv = firstNumberedLevel(from: i + 1, orderedAssetIDs: orderedAssetIDs, levels: levels),
                      nextLv > myLevel {
                foundHideable = true
            }
            i += 1
        }
        return foundHideable
    }

    // MARK: - 可见性

    static func visibleAssetIDs(
        orderedAssetIDs: [String],
        levels: [String: Int],
        collapsed: [String: Bool],
        includeGaps: Bool
    ) -> [String] {
        var visible: [String] = []
        var collapsingLevel: Int?

        for (index, id) in orderedAssetIDs.enumerated() {
            let lv = levels[id] ?? 0

            if lv == 0 {
                if let L = collapsingLevel, includeGaps,
                   let nextLv = firstNumberedLevel(from: index + 1, orderedAssetIDs: orderedAssetIDs, levels: levels),
                   nextLv > L {
                    continue
                }
                collapsingLevel = nil
                visible.append(id)
            } else if let hiding = collapsingLevel, lv > hiding {
                continue
            } else {
                collapsingLevel = nil
                visible.append(id)
                if collapsed[id] == true {
                    collapsingLevel = lv
                }
            }
        }
        return visible
    }

    // MARK: - 快捷层级（可见 Cell 统一 ±1 层）

    static func effectiveLevels(orderedAssetIDs: [String], levels: [String: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        var lastLevel = 0
        for id in orderedAssetIDs {
            guard let lv = levels[id], lv > 0 else { continue }
            let corrected = min(lv, lastLevel + 1)
            result[id] = corrected
            lastLevel = corrected
        }
        return result
    }

    static func parentNumberedAssetID(
        at index: Int,
        orderedAssetIDs: [String],
        effectiveLevels: [String: Int]
    ) -> String? {
        guard index > 0, index < orderedAssetIDs.count else { return nil }
        let childLevel = effectiveLevels[orderedAssetIDs[index]] ?? 0
        for i in stride(from: index - 1, through: 0, by: -1) {
            let id = orderedAssetIDs[i]
            guard let lv = effectiveLevels[id], lv > 0 else { continue }
            if childLevel > 0 {
                if lv < childLevel { return id }
            } else {
                return id
            }
        }
        return nil
    }

    static func applyVisibleHierarchyStep(
        expand: Bool,
        visibleIDs: Set<String>,
        orderedAssetIDs: [String],
        levels: [String: Int],
        collapsed: [String: Bool],
        spanMode: HierarchyCollapseSpanMode
    ) -> [String: Bool]? {
        guard let plan = visibleHierarchyStepPlan(
            expand: expand,
            visibleIDs: visibleIDs,
            orderedAssetIDs: orderedAssetIDs,
            levels: levels,
            collapsed: collapsed,
            spanMode: spanMode
        ) else { return nil }

        var next = collapsed
        var changed = false
        for (id, lv) in plan.candidates where lv == plan.targetLevel {
            if expand {
                if next[id] == true {
                    next.removeValue(forKey: id)
                    changed = true
                }
            } else if next[id] != true {
                next[id] = true
                changed = true
            }
        }
        return changed ? next : nil
    }

    static func canApplyVisibleHierarchyStep(
        expand: Bool,
        visibleIDs: Set<String>,
        orderedAssetIDs: [String],
        levels: [String: Int],
        collapsed: [String: Bool],
        spanMode: HierarchyCollapseSpanMode
    ) -> Bool {
        visibleHierarchyStepPlan(
            expand: expand,
            visibleIDs: visibleIDs,
            orderedAssetIDs: orderedAssetIDs,
            levels: levels,
            collapsed: collapsed,
            spanMode: spanMode
        ) != nil
    }

    private struct VisibleHierarchyStepPlan {
        let candidates: [(id: String, level: Int)]
        let targetLevel: Int
    }

    /// 计算可见区域 ±1 层折叠步进；`hasDescendants` 按 assetID 记忆化，避免对同一父节点重复 O(n) 扫描
    private static func visibleHierarchyStepPlan(
        expand: Bool,
        visibleIDs: Set<String>,
        orderedAssetIDs: [String],
        levels: [String: Int],
        collapsed: [String: Bool],
        spanMode: HierarchyCollapseSpanMode
    ) -> VisibleHierarchyStepPlan? {
        guard !visibleIDs.isEmpty else { return nil }
        let effective = effectiveLevels(orderedAssetIDs: orderedAssetIDs, levels: levels)
        var descendantsMemo: [String: Bool] = [:]
        func hasDescendantsCached(_ assetID: String) -> Bool {
            if let hit = descendantsMemo[assetID] { return hit }
            let value = hasDescendants(
                assetID: assetID,
                orderedAssetIDs: orderedAssetIDs,
                levels: levels,
                spanMode: spanMode
            )
            descendantsMemo[assetID] = value
            return value
        }

        var controlTargets: Set<String> = []
        controlTargets.reserveCapacity(min(visibleIDs.count, orderedAssetIDs.count))
        for (index, id) in orderedAssetIDs.enumerated() where visibleIDs.contains(id) {
            if let target = hierarchyControlTargetID(
                at: index,
                orderedAssetIDs: orderedAssetIDs,
                effectiveLevels: effective,
                hasDescendants: hasDescendantsCached
            ) {
                controlTargets.insert(target)
            }
        }
        guard !controlTargets.isEmpty else { return nil }

        var candidates: [(id: String, level: Int)] = []
        candidates.reserveCapacity(controlTargets.count)
        for id in controlTargets {
            guard let lv = effective[id] else { continue }
            let isCollapsed = collapsed[id] == true
            guard hasDescendantsCached(id) else { continue }
            if expand {
                if isCollapsed { candidates.append((id, lv)) }
            } else if !isCollapsed {
                candidates.append((id, lv))
            }
        }
        guard !candidates.isEmpty else { return nil }

        let targetLevel = expand
            ? candidates.map(\.level).min()
            : candidates.map(\.level).max()
        guard let level = targetLevel else { return nil }
        return VisibleHierarchyStepPlan(candidates: candidates, targetLevel: level)
    }

    // MARK: - 顺序校正（与 computeNumbers 的 correctedLv 规则一致）

    static func reconcileLevelsWithOrder(orderedAssetIDs: [String], levels: [String: Int]) -> [String: Int] {
        guard !levels.isEmpty else { return levels }
        var dict = levels
        var lastLevel = 0
        for id in orderedAssetIDs {
            guard let lv = dict[id], lv > 0 else { continue }
            let corrected = min(lv, lastLevel + 1)
            if corrected != lv {
                dict[id] = corrected
            }
            lastLevel = corrected
        }
        return dict
    }

    /// 自 `assetID` 起向上找第一个在 `visibleIDs` 中的有编号祖先
    static func nearestVisibleNumberedAncestor(
        of assetID: String,
        visibleIDs: Set<String>,
        orderedAssetIDs: [String],
        effectiveLevels: [String: Int]
    ) -> String? {
        guard let index = orderedAssetIDs.firstIndex(of: assetID) else { return nil }
        if visibleIDs.contains(assetID), (effectiveLevels[assetID] ?? 0) > 0 {
            return assetID
        }
        var requiredParent = effectiveLevels[assetID].map { $0 - 1 } ?? Int.max
        for i in stride(from: index - 1, through: 0, by: -1) {
            let id = orderedAssetIDs[i]
            guard let lv = effectiveLevels[id], lv > 0 else { continue }
            if visibleIDs.contains(id), lv <= requiredParent {
                return id
            }
            requiredParent = lv - 1
        }
        return nil
    }

    private static func hierarchyControlTargetID(
        at index: Int,
        orderedAssetIDs: [String],
        effectiveLevels: [String: Int],
        hasDescendants: (String) -> Bool
    ) -> String? {
        let id = orderedAssetIDs[index]
        let lv = effectiveLevels[id] ?? 0
        if lv > 0 {
            return hasDescendants(id)
                ? id
                : parentNumberedAssetID(at: index, orderedAssetIDs: orderedAssetIDs, effectiveLevels: effectiveLevels)
        }
        if let parent = parentNumberedAssetID(at: index, orderedAssetIDs: orderedAssetIDs, effectiveLevels: effectiveLevels),
           hasDescendants(parent) {
            return parent
        }
        for i in (index + 1)..<orderedAssetIDs.count {
            let nextID = orderedAssetIDs[i]
            let nextLv = effectiveLevels[nextID] ?? 0
            if nextLv > 0 {
                return hasDescendants(nextID) ? nextID : nil
            }
        }
        return nil
    }

    // MARK: - Private

    private static func firstNumberedLevel(from startIndex: Int, orderedAssetIDs: [String], levels: [String: Int]) -> Int? {
        var i = startIndex
        while i < orderedAssetIDs.count {
            let v = levels[orderedAssetIDs[i]] ?? 0
            if v > 0 { return v }
            i += 1
        }
        return nil
    }
}
