//
//  PhotoNumberingService.swift
//  HSPhotos
//
//  照片多级编号系统（类似 Word 多级列表，支持无限级嵌套）
//  编号由 (顺序, 层级) 纯函数计算，不可手动输入
//  运行时仅使用内存缓存，UserDefaults 仅在进入/离开视图及变更时读写
//

import Foundation
import Photos

/// 照片编号服务：存储 level(1,2,3,...)、折叠状态，按顺序计算编号（无限层级）
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

    // MARK: - 编号计算（栈式算法，支持无限级，O(n)）

    /// 根据顺序与层级计算编号，返回 assetID -> "1.2.3" 格式的字典
    func computeNumbers(
        for orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [String: String] {
        let levels = levelsCache[cacheKey(collection)] ?? [:]
        var result: [String: String] = [:]
        // counters[i] 表示第 i 层当前的计数（从下标 1 开始有效，故初始化一个 [0] 占位）
        var counters: [Int] = [0]
        var lastLevel = 0

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = levels[id] ?? 0
            guard lv > 0 else { continue }

            // 1. 结构完整性规范：层级深度不能超过前一个资产的深度 + 1 (确保有主级才有子级，且无断档)
            let correctedLv = min(lv, lastLevel + 1)

            // 2. 确保 counters 数组足够长
            while counters.count <= correctedLv {
                counters.append(0)
            }

            // 3. 重置更深层的计数器：遇到更高层级时，其下的子层级全部归零
            if correctedLv <= lastLevel {
                for i in (correctedLv + 1)..<counters.count {
                    counters[i] = 0
                }
            }

            // 4. 当前层级计数并记录
            counters[correctedLv] += 1
            lastLevel = correctedLv

            // 5. 生成字符串 (1.1.1)
            let parts = (1...correctedLv).map { String(counters[$0]) }
            result[id] = parts.joined(separator: ".")
        }
        return result
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
        let myLevel = levels[asset.localIdentifier] ?? 0
        guard myLevel > 0 else { return false }
        guard let idx = orderedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return false
        }
        for i in (idx + 1)..<orderedAssets.count {
            let lv = levels[orderedAssets[i].localIdentifier] ?? 0
            if lv == 0 { return false }          // 无层级照片，终止
            if lv <= myLevel { return false }    // 遇到同层或更高层，终止
            if lv > myLevel { return true }      // 找到更深的子节点
        }
        return false
    }

    /// 根据折叠状态返回可见照片
    /// 算法：用 collapsingLevel 追踪当前折叠的最高层级，
    /// 遇到 level <= collapsingLevel 或 level=0 时退出隐藏区域。
    func visibleAssets(
        from orderedAssets: [PHAsset],
        in collection: PHAssetCollection
    ) -> [PHAsset] {
        let key = cacheKey(collection)
        let levels = levelsCache[key] ?? [:]
        let collapsed = collapsedCache[key] ?? [:]
        var visible: [PHAsset] = []
        // 当前折叠根节点的层级（nil = 不在隐藏区域）
        var collapsingLevel: Int? = nil

        for asset in orderedAssets {
            let id = asset.localIdentifier
            let lv = levels[id] ?? 0

            if lv == 0 {
                // 无层级照片：始终可见，退出任何折叠上下文
                collapsingLevel = nil
                visible.append(asset)
            } else if let hiding = collapsingLevel, lv > hiding {
                // 在折叠区域内且比折叠根更深：隐藏
                continue
            } else {
                // 可见的层级节点（或者比折叠根同层/更浅，退出折叠）
                collapsingLevel = nil
                visible.append(asset)
                // 如果这个节点本身被折叠，开始隐藏更深的节点
                if collapsed[id] == true {
                    collapsingLevel = lv
                }
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
