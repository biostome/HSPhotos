//
//  PhotoSortPreference.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/29.
//

import Foundation
import Photos

extension UserDefaults {
    func set(preference: String, for collection: PHAssetCollection) {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        set(preference, forKey: key)
    }
    
    func preference(for collection: PHAssetCollection) -> String? {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        return string(forKey: key)
    }
}

enum PhotoSortPreference: String {
    /// 创建时间
    case creationDate = "creationDate"
    /// 修改时间
    case modificationDate = "modificationDate"
    /// 最近加入时间
    case recentDate = "recentDate"
    /// 自定义
    case custom = "custom"
    
    func preference(for collection: PHAssetCollection) -> Self {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        let value = UserDefaults.standard.string(forKey: key) ?? PhotoSortPreference.custom.rawValue
        return PhotoSortPreference(rawValue: value) ?? .custom
    }
    
    func set(preference collection: PHAssetCollection) {
        let key = "system_sort_preference_\(collection.localIdentifier)"
        UserDefaults.standard.set(self.rawValue, forKey: key)
    }
}

extension PhotoSortPreference {
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .creationDate:
            return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .recentDate:
            return [NSSortDescriptor(key: "modificationDate", ascending: false)]
        case .modificationDate:
            return [NSSortDescriptor(key: "modificationDate", ascending: false)]
        case .custom:
            return nil
        }
    }
}
