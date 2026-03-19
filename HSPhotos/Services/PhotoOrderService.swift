//
//  PhotoSortor.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/29.
//
//  运行时仅使用内存缓存，UserDefaults 仅在进入/离开视图及变更时读写
//

import Foundation
import Photos

/// 自定义排序数据
class PhotoOrder {

    private static let orderKeyPrefix = "custom_sort_order"

    // MARK: - 内存缓存

    private static var orderCache: [String: [String]] = [:]

    /// 进入相册时调用
    static func loadForCollection(_ collection: PHAssetCollection) {
        let key = key(for: collection)
        orderCache[key] = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 离开相册时调用
    static func saveForCollection(_ collection: PHAssetCollection) {
        let key = key(for: collection)
        if let order = orderCache[key] { UserDefaults.standard.set(order, forKey: key) }
    }

    private static func key(for collection: PHAssetCollection) -> String {
        "\(orderKeyPrefix)\(collection.localIdentifier)"
    }

    // MARK: - 运行时读写（纯内存）

    /// 获取自定义排序
    static func order(for collection: PHAssetCollection) -> [String] {
        orderCache[key(for: collection)] ?? []
    }

    /// 设置自定义排序（更新内存后保存）
    static func set(order photos: [PHAsset], for collection: PHAssetCollection) {
        let key = key(for: collection)
        orderCache[key] = photos.map { $0.localIdentifier }
        UserDefaults.standard.set(orderCache[key], forKey: key)
    }

    /// 清除自定义排序数据
    static func clear(order collection: PHAssetCollection) {
        let key = key(for: collection)
        orderCache[key] = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 首图管理扩展（当前未使用，保留接口）

    static func getHeaderAssets(for collection: PHAssetCollection) -> [String] {
        let key = "header_photos_\(collection.localIdentifier)"
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func setHeaderAssets(_ headerIdentifiers: [String], for collection: PHAssetCollection) {
        let key = "header_photos_\(collection.localIdentifier)"
        UserDefaults.standard.set(headerIdentifiers, forKey: key)
    }

    static func getParagraphCollapseStates(for collection: PHAssetCollection) -> [String: Bool] {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }

    static func setParagraphCollapseStates(_ states: [String: Bool], for collection: PHAssetCollection) {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        UserDefaults.standard.set(states, forKey: key)
    }

    static func clearHeaderData(for collection: PHAssetCollection) {
        let headerKey = "header_photos_\(collection.localIdentifier)"
        let collapseKey = "paragraph_collapse_\(collection.localIdentifier)"
        UserDefaults.standard.removeObject(forKey: headerKey)
        UserDefaults.standard.removeObject(forKey: collapseKey)
    }

    /// 应用自定义排序到照片数组（使用内存中的 order）
    static func apply(to assets: [PHAsset], for collection: PHAssetCollection) -> [PHAsset] {
        let savedOrder = order(for: collection)

        guard !savedOrder.isEmpty else { return assets }

        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
        var sortedAssets: [PHAsset] = []
        var usedIdentifiers = Set<String>()

        for identifier in savedOrder {
            if let asset = assetMap[identifier] {
                sortedAssets.append(asset)
                usedIdentifiers.insert(identifier)
            }
        }

        for asset in assets {
            if !usedIdentifiers.contains(asset.localIdentifier) {
                sortedAssets.append(asset)
            }
        }

        if sortedAssets.count != assets.count {
            print("自定义排序数据不完整，回退到默认排序")
            return assets
        }

        return sortedAssets
    }
}
