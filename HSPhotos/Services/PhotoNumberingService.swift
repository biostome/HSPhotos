//
//  PhotoNumberingService.swift
//  HSPhotos
//
//  照片多级编号系统（类似 Word 多级列表）
//  编号由 (顺序, 层级) 纯函数计算，不可手动输入
//  运行时仅使用内存缓存，UserDefaults 仅在进入/离开视图及变更时读写
//

import Foundation
import Photos

/// 照片编号服务：存储 level(1/2)、折叠状态，按顺序计算编号
final class PhotoNumberingService {
    static let shared = PhotoNumberingService()
    private init() {}

    // MARK: - 内存缓存（运行时仅读写此缓存，不碰 UserDefaults）

    private func cacheKey(_ collection: PHAssetCollection) -> String {
        collection.localIdentifier
    }

    /// 相册ID -> (assetID -> level)
    private var levelsCache: [String: [String: Int]] = [:]
    /// 相册ID -> (assetID -> collapsed)
    private var collapsedCache: [String: [String: Bool]] = [:]

    // MARK: - UserDefaults 读写时机（仅在进入/离开/变更时）

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

    // MARK: - 运行时只读（纯内存）

    /// 获取照片层级：1=一级, 2=二级, 0=未分级
    func level(for asset: PHAsset, in collection: PHAssetCollection) -> Int {
        levelsCache[cacheKey(collection)]?[asset.localIdentifier] ?? 0
    }

    /// 是否折叠（仅对 level=1 有效）
    func isCollapsed(_ asset: PHAsset, in collection: PHAssetCollection) -> Bool {
        collapsedCache[cacheKey(collection)]?[asset.localIdentifier] ?? false
    }

    // MARK: - 运行时写操作（更新内存后保存）

    /// 设置层级：1 或 2，0 表示清理
    func setLevel(_ level: Int, for asset: PHAsset, in collection: PHAssetCollection) {
        let key = cacheKey(collection)
        var dict = levelsCache[key] ?? [:]
        if level == 0 {
            dict.removeValue(forKey: asset.localIdentifier)
        } else {
            dict[asset.localIdentifier] = level
        }
        levelsCache[key] = dict
        saveForCollection(collection)
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
        saveForCollection(collection)
    }

    // MARK: - 编号计算（纯内存，O(n)）

    /// 根据顺序与层级计算编号（仅用内存缓存）
    func computeNumbers(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [String: String] {
        let levels = levelsCache[cacheKey(collection)] ?? [:]
        var result: [String: String] = [:]
        var mainNum = 0
        var subNum = 0

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = levels[id] ?? 0

            if lv == 1 {
                mainNum += 1
                subNum = 0
                result[id] = "\(mainNum)"
            } else if lv == 2 {
                if mainNum == 0 {
                    mainNum = 1
                    subNum = 0
                }
                subNum += 1
                result[id] = "\(mainNum).\(subNum)"
            }
        }
        return result
    }

    /// 批量计算编号与折叠状态（仅用内存缓存）
    func computeNumbersAndCollapsed(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> (numbers: [String: String], collapsed: [String: Bool]) {
        let key = cacheKey(collection)
        let levels = levelsCache[key] ?? [:]
        let collapsed = collapsedCache[key] ?? [:]
        var numbers: [String: String] = [:]
        var mainNum = 0
        var subNum = 0

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = levels[id] ?? 0

            if lv == 1 {
                mainNum += 1
                subNum = 0
                numbers[id] = "\(mainNum)"
            } else if lv == 2 {
                if mainNum == 0 {
                    mainNum = 1
                    subNum = 0
                }
                subNum += 1
                numbers[id] = "\(mainNum).\(subNum)"
            }
        }
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

    // MARK: - 可见性与折叠（仅用内存）

    /// level=1 是否有后续 level=2
    func hasDescendants(
        _ asset: PHAsset,
        in orderedAssets: [PHAsset],
        collection: PHAssetCollection
    ) -> Bool {
        let levels = levelsCache[cacheKey(collection)] ?? [:]
        guard levels[asset.localIdentifier] == 1 else { return false }
        guard let idx = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return false
        }
        for i in (idx + 1)..<orderedAssets.count {
            let lv = levels[orderedAssets[i].localIdentifier] ?? 0
            if lv == 1 { return false }
            if lv == 2 { return true }
        }
        return false
    }

    /// 根据折叠状态返回可见照片（仅用内存）
    func visibleAssets(
        from orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [PHAsset] {
        let key = cacheKey(collection)
        let levels = levelsCache[key] ?? [:]
        let collapsed = collapsedCache[key] ?? [:]
        var visible: [PHAsset] = []
        var isHiding = false

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = levels[id] ?? 0

            if lv == 1 {
                isHiding = collapsed[id] ?? false
                visible.append(asset)
            } else if isHiding {
                continue
            } else {
                visible.append(asset)
            }
        }
        return visible
    }

    // MARK: - 数据清理（更新内存后保存，loadPhoto 时调用）

    func cleanupInvalidNodes(validAssetIDs: Set<String>, for collection: PHAssetCollection) {
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
            saveForCollection(collection)
        }
    }
}
