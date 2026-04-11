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
