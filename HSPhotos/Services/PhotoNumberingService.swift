//
//  PhotoNumberingService.swift
//  HSPhotos
//
//  照片多级编号系统（类似 Word 多级列表）
//  编号由 (顺序, 层级) 纯函数计算，不可手动输入
//

import Foundation
import Photos

/// 照片编号服务：存储 level(1/2)、折叠状态，按顺序计算编号
final class PhotoNumberingService {
    static let shared = PhotoNumberingService()
    private init() {}

    // MARK: - 存储模型（只存 level 与 collapse，编号不持久化）

    private func levelsKey(_ collection: PHAssetCollection) -> String {
        "photo_numbering_levels_\(collection.localIdentifier)"
    }

    private func collapseKey(_ collection: PHAssetCollection) -> String {
        "photo_numbering_collapse_\(collection.localIdentifier)"
    }

    /// 获取照片层级：1=一级, 2=二级, 0=未分级
    func level(for asset: PHAsset, in collection: PHAssetCollection) -> Int {
        let key = levelsKey(collection)
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[asset.localIdentifier] ?? 0
    }

    /// 设置层级：1 或 2，0 表示清理
    func setLevel(_ level: Int, for asset: PHAsset, in collection: PHAssetCollection) {
        var dict = UserDefaults.standard.dictionary(forKey: levelsKey(collection)) as? [String: Int] ?? [:]
        if level == 0 {
            dict.removeValue(forKey: asset.localIdentifier)
        } else {
            dict[asset.localIdentifier] = level
        }
        UserDefaults.standard.set(dict, forKey: levelsKey(collection))
    }

    /// 清理某张照片的层级
    func clearLevel(for asset: PHAsset, in collection: PHAssetCollection) {
        setLevel(0, for: asset, in: collection)
    }

    /// 是否折叠（仅对 level=1 有效，折叠时隐藏其下 level=2）
    func isCollapsed(_ asset: PHAsset, in collection: PHAssetCollection) -> Bool {
        let key = collapseKey(collection)
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return dict[asset.localIdentifier] ?? false
    }

    /// 切换折叠状态
    func toggleCollapse(_ asset: PHAsset, in collection: PHAssetCollection) {
        var dict = UserDefaults.standard.dictionary(forKey: collapseKey(collection)) as? [String: Bool] ?? [:]
        dict[asset.localIdentifier] = !(dict[asset.localIdentifier] ?? false)
        UserDefaults.standard.set(dict, forKey: collapseKey(collection))
    }

    // MARK: - 编号计算（纯函数，O(n)）

    /// 根据顺序与层级计算编号
    /// - Parameters:
    ///   - orderedAssets: 按当前顺序排列的照片
    ///   - collection: 相册
    /// - Returns: assetId -> 编号字符串，如 "1", "1.1", "2.1"。未分级返回 nil
    func computeNumbers(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [String: String] {
        var result: [String: String] = [:]
        var mainNum = 0
        var subNum = 0

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = level(for: asset, in: collection)

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

    /// 获取某张照片的编号（需传入完整 orderedAssets 以保证一致）
    func numberString(
        for asset: PHAsset,
        in orderedAssets: [PHAsset],
        collection: PHAssetCollection
    ) -> String? {
        computeNumbers(for: orderedAssets, in: collection)[asset.localIdentifier]
    }

    // MARK: - 可见性与折叠

    /// level=1 是否有后续 level=2（用于显示折叠按钮）
    func hasDescendants(
        _ asset: PHAsset,
        in orderedAssets: [PHAsset],
        collection: PHAssetCollection
    ) -> Bool {
        guard level(for: asset, in: collection) == 1 else { return false }
        guard let idx = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return false
        }
        for i in (idx + 1)..<orderedAssets.count {
            let lv = level(for: orderedAssets[i], in: collection)
            if lv == 1 { return false }
            if lv == 2 { return true }
        }
        return false
    }

    /// 根据折叠状态返回可见照片（折叠 level1 时隐藏其下直至下一 level1 的所有项）
    func visibleAssets(
        from orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [PHAsset] {
        var visible: [PHAsset] = []
        var isHiding = false

        for asset in orderedAssets {
            let lv = level(for: asset, in: collection)

            if lv == 1 {
                isHiding = isCollapsed(asset, in: collection)
                visible.append(asset)
            } else if isHiding {
                continue
            } else {
                visible.append(asset)
            }
        }
        return visible
    }

    // MARK: - 数据清理

    func cleanupInvalidNodes(validAssetIDs: Set<String>, for collection: PHAssetCollection) {
        let levelsKey = levelsKey(collection)
        let collapseKey = collapseKey(collection)
        var levels = UserDefaults.standard.dictionary(forKey: levelsKey) as? [String: Int] ?? [:]
        var collapsed = UserDefaults.standard.dictionary(forKey: collapseKey) as? [String: Bool] ?? [:]
        let beforeL = levels.count
        let beforeC = collapsed.count
        levels = levels.filter { validAssetIDs.contains($0.key) }
        collapsed = collapsed.filter { validAssetIDs.contains($0.key) }
        if levels.count != beforeL { UserDefaults.standard.set(levels, forKey: levelsKey) }
        if collapsed.count != beforeC { UserDefaults.standard.set(collapsed, forKey: collapseKey) }
    }
}
