//
//  AlbumSession+Hierarchy.swift
//  HSPhotos
//
//  层级编号：查询与单张/批量变更（UI 经此访问，禁止直连 PhotoNumberingService）。
//

import Photos

extension AlbumSession {

    // MARK: - 查询

    func level(for asset: PHAsset) -> Int {
        numbering.level(for: asset, in: collection)
    }

    func isCollapsed(_ asset: PHAsset) -> Bool {
        numbering.isCollapsed(asset, in: collection)
    }

    func hasDescendants(_ asset: PHAsset, in orderedSlice: [PHAsset]) -> Bool {
        numbering.hasDescendants(asset, in: orderedSlice, collection: collection)
    }

    /// 在可见序列中，位于 `asset` 之前、最近一个 level > 0 的层级（用于同级/子级参考）。
    func previousNumberedLevel(before asset: PHAsset, in visibleRows: [PHAsset]) -> Int {
        guard let idx = visibleRows.firstIndex(of: asset), idx > 0 else { return 0 }
        for i in (0..<idx).reversed() {
            let lv = numbering.level(for: visibleRows[i], in: collection)
            if lv > 0 { return lv }
        }
        return 0
    }

    func computeNumbersAndCollapsed(for orderedSlice: [PHAsset]) -> (
        numbers: [String: String],
        collapsed: [String: Bool]
    ) {
        numbering.computeNumbersAndCollapsed(for: orderedSlice, in: collection)
    }

    func nearestCollapsibleAncestor(
        from asset: PHAsset,
        in orderedSlice: [PHAsset],
        shouldBecomeCollapsed: Bool
    ) -> PHAsset? {
        numbering.nearestCollapsibleAncestor(
            from: asset,
            in: orderedSlice,
            collection: collection,
            shouldBecomeCollapsed: shouldBecomeCollapsed
        )
    }

    // MARK: - 单张

    func setLevel(_ level: Int, for asset: PHAsset) {
        numbering.setLevel(level, for: asset, in: collection)
    }

    func clearLevelCascading(anchor: PHAsset, visibleSuccessors: [PHAsset]) {
        let anchorLevel = numbering.level(for: anchor, in: collection)
        numbering.beginBatchUpdates(for: collection)
        defer { numbering.endBatchUpdates(for: collection) }
        numbering.clearLevel(for: anchor, in: collection)
        guard anchorLevel > 0, let idx = visibleSuccessors.firstIndex(of: anchor) else { return }
        for i in (idx + 1)..<visibleSuccessors.count {
            let next = visibleSuccessors[i]
            let nextLv = numbering.level(for: next, in: collection)
            if nextLv == 0 || nextLv <= anchorLevel { break }
            numbering.clearLevel(for: next, in: collection)
        }
    }

    func toggleCollapse(_ asset: PHAsset) {
        numbering.toggleCollapse(asset, in: collection)
    }

    // MARK: - 批量

    func applyBatchSetLevel(_ level: Int, to selected: [PHAsset]) {
        makeHierarchyEditor().applySetLevel(level, to: selected)
    }

    func applyBatchPromote(to selected: [PHAsset]) {
        makeHierarchyEditor().applyPromote(to: selected)
    }

    func applyBatchDemote(to selected: [PHAsset]) {
        makeHierarchyEditor().applyDemote(to: selected)
    }

    func applyBatchClear(to selected: [PHAsset]) {
        makeHierarchyEditor().applyClear(to: selected)
    }

    func levelBeforeInMembers(_ asset: PHAsset) -> Int {
        makeHierarchyEditor().levelBefore(asset)
    }

    func makeHierarchyEditor() -> PhotoHierarchyBatchEditing {
        PhotoHierarchyBatchEditing(collection: collection, orderedAssets: memberAssets, numbering: numbering)
    }
}
