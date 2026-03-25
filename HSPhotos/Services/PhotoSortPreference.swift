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
    case creationDate = "creationDate"
    case modificationDate = "modificationDate"
    case recentDate = "recentDate"
    case custom = "custom"

    /// 首次访问时从 UserDefaults 加载并缓存，后续从内存读取
    func preference(for collection: PHAssetCollection) -> Self {
        let key = "\(preferenceKeyPrefix)\(collection.localIdentifier)"
        if let cached = PhotoSortPreference._cache[key] {
            return cached
        }
        let value = UserDefaults.standard.string(forKey: key) ?? rawValue
        let pref = PhotoSortPreference(rawValue: value) ?? .custom
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
}

extension PhotoSortPreference {
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .creationDate:
            return [NSSortDescriptor(key: "creationDate", ascending: true)]
        case .recentDate:
            return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .modificationDate:
            return [NSSortDescriptor(key: "modificationDate", ascending: false)]
        case .custom:
            return nil
        }
    }
}
