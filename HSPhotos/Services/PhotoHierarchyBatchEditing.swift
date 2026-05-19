//
//  PhotoHierarchyBatchEditing.swift
//  HSPhotos
//
//  相簿内批量层级编号（升/降/清除/设级），与 UI 解耦。
//

import Photos

struct PhotoHierarchyBatchEditing {
    let collection: PHAssetCollection
    let orderedAssets: [PHAsset]
    private let numbering: PhotoNumberingService

    init(
        collection: PHAssetCollection,
        orderedAssets: [PHAsset],
        numbering: PhotoNumberingService = .shared
    ) {
        self.collection = collection
        self.orderedAssets = orderedAssets
        self.numbering = numbering
    }

    func levelBefore(_ asset: PHAsset) -> Int {
        guard let index = indexMap[asset.localIdentifier], index > 0 else { return 0 }
        return numbering.level(for: orderedAssets[index - 1], in: collection)
    }

    func applySetLevel(_ level: Int, to selected: [PHAsset]) {
        guard !selected.isEmpty else { return }
        numbering.beginBatchUpdates(for: collection)
        defer { numbering.endBatchUpdates(for: collection) }
        for asset in selected {
            numbering.setLevel(level, for: asset, in: collection)
        }
    }

    func applyPromote(to selected: [PHAsset]) {
        guard !selected.isEmpty else { return }
        var processedIDs = Set<String>()
        numbering.beginBatchUpdates(for: collection)
        defer { numbering.endBatchUpdates(for: collection) }

        for asset in selected {
            if processedIDs.contains(asset.localIdentifier) { continue }
            let current = numbering.level(for: asset, in: collection)
            if current == 0 {
                numbering.setLevel(1, for: asset, in: collection)
                processedIDs.insert(asset.localIdentifier)
            } else if current == 1 {
                clearLevelCascading(asset: asset, processedIDs: &processedIDs)
            } else {
                shiftLevelCascading(asset: asset, delta: -1, processedIDs: &processedIDs)
            }
        }
    }

    func applyDemote(to selected: [PHAsset]) {
        guard !selected.isEmpty else { return }
        var processedIDs = Set<String>()
        numbering.beginBatchUpdates(for: collection)
        defer { numbering.endBatchUpdates(for: collection) }

        for asset in selected {
            if processedIDs.contains(asset.localIdentifier) { continue }
            let current = numbering.level(for: asset, in: collection)
            if current == 0 {
                let prev = levelBefore(asset)
                let entryLevel = prev > 0 ? prev + 1 : 1
                numbering.setLevel(entryLevel, for: asset, in: collection)
                processedIDs.insert(asset.localIdentifier)
            } else {
                shiftLevelCascading(asset: asset, delta: 1, processedIDs: &processedIDs)
            }
        }
    }

    func applyClear(to selected: [PHAsset]) {
        guard !selected.isEmpty else { return }
        var processedIDs = Set<String>()
        numbering.beginBatchUpdates(for: collection)
        defer { numbering.endBatchUpdates(for: collection) }

        for asset in selected {
            if processedIDs.contains(asset.localIdentifier) { continue }
            clearLevelCascading(asset: asset, processedIDs: &processedIDs)
        }
    }

    // MARK: - Private

    private var indexMap: [String: Int] {
        var map: [String: Int] = [:]
        map.reserveCapacity(orderedAssets.count)
        for (index, asset) in orderedAssets.enumerated() {
            map[asset.localIdentifier] = index
        }
        return map
    }

    private func shiftLevelCascading(asset: PHAsset, delta: Int, processedIDs: inout Set<String>) {
        let oldLevel = numbering.level(for: asset, in: collection)
        guard oldLevel > 0 else { return }

        let newLevel = max(1, oldLevel + delta)
        numbering.setLevel(newLevel, for: asset, in: collection)
        processedIDs.insert(asset.localIdentifier)

        guard let idx = indexMap[asset.localIdentifier] else { return }
        for i in (idx + 1)..<orderedAssets.count {
            let next = orderedAssets[i]
            let nextLevel = numbering.level(for: next, in: collection)
            if nextLevel == 0 || nextLevel <= oldLevel { break }
            numbering.setLevel(max(1, nextLevel + delta), for: next, in: collection)
            processedIDs.insert(next.localIdentifier)
        }
    }

    private func clearLevelCascading(asset: PHAsset, processedIDs: inout Set<String>) {
        let myLevel = numbering.level(for: asset, in: collection)
        numbering.clearLevel(for: asset, in: collection)
        processedIDs.insert(asset.localIdentifier)

        guard myLevel > 0, let idx = indexMap[asset.localIdentifier] else { return }
        for i in (idx + 1)..<orderedAssets.count {
            let child = orderedAssets[i]
            let childLevel = numbering.level(for: child, in: collection)
            if childLevel == 0 || childLevel <= myLevel { break }
            numbering.clearLevel(for: child, in: collection)
            processedIDs.insert(child.localIdentifier)
        }
    }
}
