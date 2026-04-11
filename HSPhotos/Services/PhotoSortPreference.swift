//
//  PhotoSortPreference.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/29.
//
//  运行时仅使用内存缓存，UserDefaults 仅在首次读取及变更时读写
//

import Foundation
import Photos

private let preferenceKeyPrefix = "system_sort_preference_"

enum PhotoSortPreference: String {
    /// 按拍摄日期排序
    case creationDate = "creationDate"
    /// 按修改时间排序
    case modificationDate = "modificationDate"
    /// 按最近加入时间排序
    case recentDate = "recentDate"
    /// 按自定义顺序排序
    case custom = "custom"
    /// 按最旧的排最前面
    case oldest = "oldest"
    /// 按最新的排最前排序
    case newest = "newest"

    var title: String {
        switch self {
        case .creationDate:
            return "按拍摄日期排序"
        case .recentDate:
            return "按最近加入时间排序"
        case .modificationDate:
            return "按修改时间排序"
        case .oldest:
            return "按最旧的排最前排序"
        case .newest:
            return "按最新的排最前排序"
        case .custom:
            return "按自定义顺序排序"
        }
    }

    init?(for collection: PHAssetCollection) {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        let rawValue = UserDefaults.standard.string(forKey: key) ?? "custom"
        self.init(rawValue: rawValue)
    }

    func save(for collection: PHAssetCollection) {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        UserDefaults.standard.set(self.rawValue, forKey: key)
    }

    func set(preference collection: PHAssetCollection) {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        UserDefaults.standard.set(self.rawValue, forKey: key)
    }

    func clear(for collection: PHAssetCollection) {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    func preference(for collection: PHAssetCollection) -> PhotoSortPreference {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        let rawValue = UserDefaults.standard.string(forKey: key) ?? "custom"
        return PhotoSortPreference(rawValue: rawValue) ?? .custom
    }
}

extension PhotoSortPreference {
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .creationDate:
            return [
                NSSortDescriptor(key: "creationDate", ascending: true),
                NSSortDescriptor(key: "modificationDate", ascending: true),
            ]
        case .oldest:
            return [
                NSSortDescriptor(key: "creationDate", ascending: true),
                NSSortDescriptor(key: "modificationDate", ascending: true),
            ]
        case .newest:
            // 与 `oldest` 对称：仅按拍摄/元数据创建时间，新→前（显式 descriptor，不依赖 fetch 默认顺序）
            return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .recentDate:
            return [
                NSSortDescriptor(key: "modificationDate", ascending: false),
                NSSortDescriptor(key: "creationDate", ascending: false),
            ]
        case .modificationDate:
            return [
                NSSortDescriptor(key: "modificationDate", ascending: false),
                NSSortDescriptor(key: "creationDate", ascending: false),
            ]
        case .custom:
            // 不显式排序键 → `PHFetchOptions.sortDescriptors == nil`，顺序以系统相册为准（与「照片」一致）。
            return nil
        }
    }
}
