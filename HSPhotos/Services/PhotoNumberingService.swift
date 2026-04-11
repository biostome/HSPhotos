//
//  PhotoNumberingService.swift
//  HSPhotos
//
//  照片多级编号系统（类似 Word 多级列表，支持无限级嵌套）
//  编号由 (顺序, 层级) 纯函数计算，不可手动输入
//  运行时在内存缓存中读写；UserDefaults 在进入相册时 load、离开时 save，且每次变更（默认）或批量收尾时也会写入。
//

import Foundation
import Photos

/// 照片编号服务：存储 level(1,2,3,...)、折叠状态，按顺序计算编号（无限层级）
final class PhotoNumberingService {
    static let shared = PhotoNumberingService()
    private init() {}

    // MARK: - 内存缓存（编号逻辑只读此缓存；落盘见 persistAfterMutation / saveForCollection）

    private func cacheKey(_ collection: PHAssetCollection) -> String {
        collection.localIdentifier
    }

    /// 相册ID -> (assetID -> level)
    private var levelsCache: [String: [String: Int]] = [:]
    /// 相册ID -> (assetID -> collapsed)
    private var collapsedCache: [String: [String: Bool]] = [:]
    /// 合并持久化：批量改 level 时每项都写 UserDefaults 会序列化整表数万次，用深度计数收尾写一次
    private var persistenceBatchDepth: [String: Int] = [:]

    // MARK: - UserDefaults（进入时加载、离开时保存；单次操作后默认立即持久化；begin/endBatchUpdates 期间合并写入）

    private func levelsKey(_ collection: PHAssetCollection) -> String {
        "photo_numbering_levels_\(collection.localIdentifier)"
    }

    private func collapseKey(_ collection: PHAssetCollection) -> String {
        "photo_numbering_collapse_\(collection.localIdentifier)"
    }

    /// 进入相册时调用：从 UserDefaults 加载到内存
    func loadForCollection(_ collection: PHAssetCollection) {
        let key = cacheKey(collection)
        levelsCache[key] = (UserDefaults.standard.dictionary(forKey: levelsKey(collection)) as? [String: Int]) ?? [:]
        collapsedCache[key] = (UserDefaults.standard.dictionary(forKey: collapseKey(collection)) as? [String: Bool]) ?? [:]
    }

    /// 离开相册或数据变更时调用：从内存持久化到 UserDefaults
    func saveForCollection(_ collection: PHAssetCollection) {
        let key = cacheKey(collection)
        if let levels = levelsCache[key] { UserDefaults.standard.set(levels, forKey: levelsKey(collection)) }
        if let collapsed = collapsedCache[key] { UserDefaults.standard.set(collapsed, forKey: collapseKey(collection)) }
    }

    /// 与 `endBatchUpdates` 成对使用，期间 `setLevel` / `toggleCollapse` / 内部 reconcile 不落盘，结束时写一次
    func beginBatchUpdates(for collection: PHAssetCollection) {
        let k = cacheKey(collection)
        persistenceBatchDepth[k, default: 0] += 1
    }

    func endBatchUpdates(for collection: PHAssetCollection) {
        let k = cacheKey(collection)
        guard let d = persistenceBatchDepth[k], d > 0 else { return }
        if d == 1 {
            persistenceBatchDepth[k] = nil
            saveForCollection(collection)
        } else {
            persistenceBatchDepth[k] = d - 1
        }
    }

    private func isPersistenceBatching(_ collection: PHAssetCollection) -> Bool {
        (persistenceBatchDepth[cacheKey(collection)] ?? 0) > 0
    }

    private func persistAfterMutation(for collection: PHAssetCollection) {
        guard !isPersistenceBatching(collection) else { return }
        saveForCollection(collection)
    }

    // MARK: - 运行时只读（纯内存）

    /// 获取照片层级（1 = 最顶层，2,3,... 依次深入，0 = 无层级）
    func level(for asset: PHAsset, in collection: PHAssetCollection) -> Int {
        levelsCache[cacheKey(collection)]?[asset.localIdentifier] ?? 0
    }

    /// 是否折叠
    func isCollapsed(_ asset: PHAsset, in collection: PHAssetCollection) -> Bool {
        collapsedCache[cacheKey(collection)]?[asset.localIdentifier] ?? false
    }

    // MARK: - 运行时写操作（更新内存后保存）

    /// 设置层级（level >= 1），0 表示清除层级
    func setLevel(_ level: Int, for asset: PHAsset, in collection: PHAssetCollection) {
        let key = cacheKey(collection)
        var dict = levelsCache[key] ?? [:]
        if level <= 0 {
            dict.removeValue(forKey: asset.localIdentifier)
        } else {
            dict[asset.localIdentifier] = level
        }
        levelsCache[key] = dict
        persistAfterMutation(for: collection)
    }

    /// 清理某张照片的层级
    func clearLevel(for asset: PHAsset, in collection: PHAssetCollection) {
        setLevel(0, for: asset, in: collection)
    }

    /// 切换折叠状态
    func toggleCollapse(_ asset: PHAsset, in collection: PHAssetCollection) {
        let key = cacheKey(collection)
        var dict = collapsedCache[key] ?? [:]
        dict[asset.localIdentifier] = !(dict[asset.localIdentifier] ?? false)
        collapsedCache[key] = dict
        persistAfterMutation(for: collection)
    }

    // MARK: - 编号计算（栈式算法，支持无限级，O(n)）

    /// 根据顺序与层级计算编号，返回 assetID -> "1.2.3" 格式的字典
    func computeNumbers(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [String: String] {
        let levels = levelsCache[cacheKey(collection)] ?? [:]
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        return PhotoNumberingLogic.computeNumbers(orderedAssetIDs: orderedIDs, levels: levels)
    }

    /// 批量计算编号与折叠状态（仅用内存缓存）
    func computeNumbersAndCollapsed(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> (numbers: [String: String], collapsed: [String: Bool]) {
        let numbers = computeNumbers(for: orderedAssets, in: collection)
        let collapsed = collapsedCache[cacheKey(collection)] ?? [:]
        return (numbers, collapsed)
    }

    /// 获取某张照片的编号
    func numberString(
        for asset: PHAsset,
        in orderedAssets: [PHAsset],
        collection: PHAssetCollection
    ) -> String? {
        computeNumbers(for: orderedAssets, in: collection)[asset.localIdentifier]
    }

    // MARK: - 可见性与折叠（栈式算法，支持无限级）

    /// 某个层级节点是否有比自己更深的子节点
    func hasDescendants(
        _ asset: PHAsset,
        in orderedAssets: [PHAsset],
        collection: PHAssetCollection
    ) -> Bool {
        let levels = levelsCache[cacheKey(collection)] ?? [:]
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        return PhotoNumberingLogic.hasDescendants(
            assetID: asset.localIdentifier,
            orderedAssetIDs: orderedIDs,
            levels: levels,
            spanMode: HierarchyCollapseSettings.shared.spanMode
        )
    }

    /// 根据折叠状态返回可见照片
    /// 算法：用 collapsingLevel 追踪当前折叠的最高层级；
    /// 「遇无编号断开」时 level=0 会退出隐藏区域；
    /// 「折叠含间隙」时：仅当其后第一个有编号项仍比折叠根更深时，该无编号项才随折叠隐藏（同级/更浅边界外的间隙仍显示）。
    func visibleAssets(
        from orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [PHAsset] {
        let key = cacheKey(collection)
        let levels = levelsCache[key] ?? [:]
        let collapsed = collapsedCache[key] ?? [:]
        let includeGaps = HierarchyCollapseSettings.shared.spanMode == .includeGaps
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        let visibleIDs = PhotoNumberingLogic.visibleAssetIDs(
            orderedAssetIDs: orderedIDs,
            levels: levels,
            collapsed: collapsed,
            includeGaps: includeGaps
        )
        var idToAsset: [String: PHAsset] = [:]
        idToAsset.reserveCapacity(orderedAssets.count)
        for asset in orderedAssets {
            idToAsset[asset.localIdentifier] = asset
        }
        return visibleIDs.compactMap { idToAsset[$0] }
    }

    // MARK: - 数据清理（更新内存后保存，loadPhoto 时调用）

    /// 按当前顺序将已存储的 level 写回为与 `computeNumbers` 一致的合法值（例如父节点删除后子级 depth 回落）。
    private func reconcileStoredLevelsWithOrder(orderedAssets: [PHAsset], in collection: PHAssetCollection) {
        let key = cacheKey(collection)
        guard let dict = levelsCache[key], !dict.isEmpty else { return }
        let orderedIDs = orderedAssets.map(\.localIdentifier)
        let reconciled = PhotoNumberingLogic.reconcileLevelsWithOrder(orderedAssetIDs: orderedIDs, levels: dict)
        if reconciled != dict {
            levelsCache[key] = reconciled
            persistAfterMutation(for: collection)
        }
    }

    /// - Parameter orderedAssets: 若传入，在过滤无效 ID 后按该顺序校正剩余节点的存储层级并持久化。
    func cleanupInvalidNodes(validAssetIDs: Set<String>, orderedAssets: [PHAsset]? = nil, for collection: PHAssetCollection) {
        let key = cacheKey(collection)
        var levels = levelsCache[key] ?? [:]
        var collapsed = collapsedCache[key] ?? [:]
        let beforeL = levels.count
        let beforeC = collapsed.count
        levels = levels.filter { validAssetIDs.contains($0.key) }
        collapsed = collapsed.filter { validAssetIDs.contains($0.key) }
        levelsCache[key] = levels
        collapsedCache[key] = collapsed
        if levels.count != beforeL || collapsed.count != beforeC {
            persistAfterMutation(for: collection)
        }
        if let order = orderedAssets, !order.isEmpty {
            reconcileStoredLevelsWithOrder(orderedAssets: order, in: collection)
        }
    }
}
