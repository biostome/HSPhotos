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

