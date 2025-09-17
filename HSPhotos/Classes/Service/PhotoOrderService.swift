//
//  PhotoSortor.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/29.
//

import Foundation
import Photos

extension UserDefaults {
    /// 获取自定义排序
    /// - Parameter collection: 相册
    /// - Returns: 自定义排序
    func order(for collection: PHAssetCollection) -> [String] {
        let key = "custom_sort_order\(collection.localIdentifier)"
        return stringArray(forKey: key) ?? []
    }

    /// 设置自定义排序
    /// - Parameters:
    ///   - photos: 照片数组
    ///   - collection: 相册
    func set(order photos: [PHAsset], for collection: PHAssetCollection ) {
        let key = "custom_sort_order\(collection.localIdentifier)"
        let identifiers = photos.map { $0.localIdentifier }
        set(identifiers, forKey: key)
    }

    /// 清除自定义排序数据
    /// - Parameter collection: 相册
    /// - Returns: void
    func clear(order collection: PHAssetCollection) {
        let key = "custom_sort_order\(collection.localIdentifier)"
        removeObject(forKey: key)
    }
}

/// 自定义排序数据
class PhotoOrder {
    
    /// 获取自定义排序
    /// - Parameter collection: 相册
    static func order(for collection: PHAssetCollection) -> [String] {
        return UserDefaults.standard.order(for: collection)
    }
    
    /// 设置自定义排序
    /// - Parameters:
    ///   - photos: 照片数组
    ///   - collection: 相册
    static func set(order photos: [PHAsset], for collection: PHAssetCollection ) {
        UserDefaults.standard.set(order: photos, for: collection)
    }
    
    /// 清除自定义排序数据
    /// - Parameter collection: 相册
    static func clear(order collection: PHAssetCollection) {
        UserDefaults.standard.clear(order: collection)
    }
    
    // MARK: - 首图管理扩展
    
    /// 获取首图列表
    /// - Parameter collection: 相册
    /// - Returns: 首图标识符数组
    static func getHeaderAssets(for collection: PHAssetCollection) -> [String] {
        let key = "header_photos_\(collection.localIdentifier)"
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }
    
    /// 设置首图列表
    /// - Parameters:
    ///   - headerIdentifiers: 首图标识符数组
    ///   - collection: 相册
    static func setHeaderAssets(_ headerIdentifiers: [String], for collection: PHAssetCollection) {
        let key = "header_photos_\(collection.localIdentifier)"
        UserDefaults.standard.set(headerIdentifiers, forKey: key)
    }
    
    /// 获取段落折叠状态
    /// - Parameter collection: 相册
    /// - Returns: 段落折叠状态字典
    static func getParagraphCollapseStates(for collection: PHAssetCollection) -> [String: Bool] {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }
    
    /// 设置段落折叠状态
    /// - Parameters:
    ///   - states: 段落折叠状态字典
    ///   - collection: 相册
    static func setParagraphCollapseStates(_ states: [String: Bool], for collection: PHAssetCollection) {
        let key = "paragraph_collapse_\(collection.localIdentifier)"
        UserDefaults.standard.set(states, forKey: key)
    }
    
    /// 清除首图相关数据
    /// - Parameter collection: 相册
    static func clearHeaderData(for collection: PHAssetCollection) {
        let headerKey = "header_photos_\(collection.localIdentifier)"
        let collapseKey = "paragraph_collapse_\(collection.localIdentifier)"
        UserDefaults.standard.removeObject(forKey: headerKey)
        UserDefaults.standard.removeObject(forKey: collapseKey)
    }
    
    /// 应用自定义排序到照片数组
    /// - Parameters:
    ///   - assets: 原始照片数组
    ///   - collection: 相册
    /// - Returns: 排序后的照片数组
    static func apply(to assets: [PHAsset], for collection: PHAssetCollection) -> [PHAsset] {
        let savedOrder = UserDefaults.standard.order(for: collection)
        
        // 如果没有保存的排序顺序，返回原数组
        guard !savedOrder.isEmpty else {
            return assets
        }
        
        // 创建标识符到资产的映射
        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
        
        // 按保存的顺序重新排列
        var sortedAssets: [PHAsset] = []
        var usedIdentifiers = Set<String>()
        
        // 首先按照保存的顺序添加照片
        for identifier in savedOrder {
            if let asset = assetMap[identifier] {
                sortedAssets.append(asset)
                usedIdentifiers.insert(identifier)
            }
        }
        
        // 然后添加新的照片（不在保存的顺序中的照片）到末尾
        for asset in assets {
            if !usedIdentifiers.contains(asset.localIdentifier) {
                sortedAssets.append(asset)
            }
        }
        
        // 验证数据完整性
        if sortedAssets.count != assets.count {
            // 数据有问题，回退到默认排序
            print("自定义排序数据不完整，回退到默认排序")
            return assets
        }
        
        return sortedAssets
    }
    
}

