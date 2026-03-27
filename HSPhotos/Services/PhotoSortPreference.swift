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
    // 首页（图库）
    case homeRecentAdded = "homeRecentAdded"
    case homeCaptureDate = "homeCaptureDate"
    // 相册内
    case albumOldestFirst = "albumOldestFirst"
    case albumNewestFirst = "albumNewestFirst"
    case albumCustom = "albumCustom"

    /// 首次访问时从 UserDefaults 加载并缓存，后续从内存读取
    func preference(for collection: PHAssetCollection) -> Self {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        if let cached = PhotoSortPreference._cache[key] {
            return cached
        }
        let value = UserDefaults.standard.string(forKey: key) ?? rawValue
        let pref: PhotoSortPreference
        if let current = PhotoSortPreference(rawValue: value) {
            pref = current
        } else {
            // 兼容历史枚举值，按页面语义自动迁移
            pref = PhotoSortPreference.mapLegacyPreference(value, for: collection)
            UserDefaults.standard.set(pref.rawValue, forKey: key)
        }
        PhotoSortPreference._cache[key] = pref
        return pref
    }

    /// 变更时更新缓存并保存
    func set(preference collection: PHAssetCollection) {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        PhotoSortPreference._cache[key] = self
        UserDefaults.standard.set(self.rawValue, forKey: key)
    }

    fileprivate static var _cache: [String: PhotoSortPreference] = [:]

    private static func mapLegacyPreference(_ value: String, for collection: PHAssetCollection) -> PhotoSortPreference {
        let isHomeCollection = collection.assetCollectionSubtype == .smartAlbumUserLibrary
        switch value {
        case "creationDate":
            return isHomeCollection ? .homeCaptureDate : .albumOldestFirst
        case "recentDate", "modificationDate":
            return isHomeCollection ? .homeRecentAdded : .albumNewestFirst
        case "custom":
            return isHomeCollection ? .homeRecentAdded : .albumCustom
        default:
            return isHomeCollection ? .homeRecentAdded : .albumCustom
        }
    }
}

extension PhotoSortPreference {
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .homeCaptureDate, .albumOldestFirst:
            return [NSSortDescriptor(key: "creationDate", ascending: true)]
        case .albumNewestFirst:
            return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .homeRecentAdded, .albumCustom:
            return nil
        }
    }
}
