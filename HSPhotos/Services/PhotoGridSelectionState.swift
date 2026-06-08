//
//  PhotoGridSelectionState.swift
//  HSPhotos
//
//  网格多选序号的纯逻辑（无 UIKit / PHAsset），便于单测并与 PhotoGridView 解耦。
//

import Foundation

/// 维护「资源 localIdentifier → 选中序号(1 起、取消选中后会压缩连续)」的状态。
struct PhotoGridSelectionState: Equatable, Sendable {
    private(set) var rankByID: [String: Int]
    private var orderedIDCache: [String]
    private var nextRank: Int

    init(rankByID: [String: Int] = [:]) {
        self.rankByID = rankByID
        self.orderedIDCache = rankByID.sorted { $0.value < $1.value }.map(\.key)
        self.nextRank = (rankByID.values.max() ?? 0) + 1
    }

    var count: Int { rankByID.count }

    func rank(for id: String) -> Int? {
        rankByID[id]
    }

    func contains(_ id: String) -> Bool {
        rankByID[id] != nil
    }

    /// 当前选中 id 集合（O(n)，无 PHAsset 分配），用于按相册顺序过滤等。
    var selectedIdentifierSet: Set<String> {
        Set(rankByID.keys)
    }

    /// 按选中序号升序排列的 id。
    var orderedIDs: [String] {
        orderedIDCache
    }

    var lastSelectedID: String? {
        orderedIDCache.last
    }

    mutating func clear() {
        rankByID.removeAll(keepingCapacity: false)
        orderedIDCache.removeAll(keepingCapacity: false)
        nextRank = 1
    }

    /// 与 `selectAll()` 一致：按给定顺序赋予 1…n。
    mutating func replaceAll(orderedIDs: [String]) {
        rankByID.removeAll(keepingCapacity: true)
        rankByID.reserveCapacity(orderedIDs.count)
        orderedIDCache = orderedIDs
        for (index, id) in orderedIDs.enumerated() {
            rankByID[id] = index + 1
        }
        nextRank = orderedIDs.count + 1
    }

    /// 切换选中。返回「序号发生变化的其它 id」（不含刚被取消选中的 id），供局部刷新。
    mutating func toggle(id: String) -> [String] {
        if rankByID[id] != nil {
            rankByID.removeValue(forKey: id)
            orderedIDCache.removeAll { $0 == id }
            var updatedIDs: [String] = []
            for (index, other) in orderedIDCache.enumerated() {
                let newRank = index + 1
                guard rankByID[other] != newRank else { continue }
                rankByID[other] = newRank
                updatedIDs.append(other)
            }
            nextRank = rankByID.count + 1
            return updatedIDs
        } else {
            rankByID[id] = nextRank
            orderedIDCache.append(id)
            nextRank += 1
            return []
        }
    }

    /// 若未选中则追加到末尾序号（与范围选择、滑选增量一致）。
    @discardableResult
    mutating func insertIfAbsent(id: String) -> Bool {
        if rankByID[id] != nil { return false }
        rankByID[id] = nextRank
        orderedIDCache.append(id)
        nextRank += 1
        return true
    }

    /// 仅从选中集中移除，不压缩其它项的序号（与删除资源后原 `selectedMap.removeValue` 行为一致）。
    mutating func removeIdentifierWithoutRankShift(id: String) {
        rankByID.removeValue(forKey: id)
        orderedIDCache.removeAll { $0 == id }
    }

    /// 批量移除并一次性重编序号，避免逐项 toggle 导致的 O(n²) 压缩。
    /// - Returns: 所有序号发生过变化的 id（不含被移除的 id）。
    mutating func removeMultiple(ids: Set<String>) -> [String] {
        for id in ids {
            rankByID.removeValue(forKey: id)
        }
        orderedIDCache.removeAll { ids.contains($0) }
        var changed: [String] = []
        var newRank = 1
        for id in orderedIDCache {
            if rankByID[id] != newRank {
                changed.append(id)
                rankByID[id] = newRank
            }
            newRank += 1
        }
        nextRank = rankByID.count + 1
        return changed
    }
}
