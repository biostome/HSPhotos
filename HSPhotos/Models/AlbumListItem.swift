//
//  AlbumListItem.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import Photos

/// 相册列表项类型
enum AlbumListItemType {
    case folder(PHCollectionList)  // 文件夹
    case album(PHAssetCollection)  // 相册
}

/// 相册列表项
class AlbumListItem {
    let type: AlbumListItemType
    let title: String
    let localIdentifier: String
    
    /// 获取子文件夹数量（简化实现：返回 0）
    var subFolderCount: Int {
        switch type {
        case .album:
            return 0
        case .folder:
            // 由于 iOS Photos 框架限制，暂时返回 0
            return 0
        }
    }
    
    /// 获取子相册数量（简化实现：返回 0）
    var subAlbumCount: Int {
        switch type {
        case .album:
            return 0
        case .folder:
            // 由于 iOS Photos 框架限制，暂时返回 0
            return 0
        }
    }
    
    /// 获取封面照片（文件夹获取第一个子相册的封面）
    var coverAsset: PHAsset? {
        switch type {
        case .album(let collection):
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            return assets.firstObject
        case .folder:
            // 文件夹获取第一个子相册的封面
            let fetchOptions = PHFetchOptions()
            fetchOptions.fetchLimit = 1
            // 获取所有相册
            let allAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            guard let album = allAlbums.firstObject else { return nil }
            let assets = PHAsset.fetchAssets(in: album, options: nil)
            return assets.firstObject
        }
    }
    
    /// 获取项目数量（文件夹返回子文件夹 + 子相册总数，相册返回照片数）
    var itemCount: Int {
        switch type {
        case .album(let collection):
            return PHAsset.fetchAssets(in: collection, options: nil).count
        case .folder:
            // 文件夹：返回子文件夹和子相册的总数（简化为 0）
            return 0
        }
    }
    
    init(type: AlbumListItemType) {
        self.type = type
        switch type {
        case .folder(let collectionList):
            self.title = collectionList.localizedTitle ?? "未命名文件夹"
            self.localIdentifier = collectionList.localIdentifier
        case .album(let collection):
            self.title = collection.localizedTitle ?? "未命名相册"
            self.localIdentifier = collection.localIdentifier
        }
    }
    
    /// 判断是否为文件夹
    var isFolder: Bool {
        if case .folder = type {
            return true
        }
        return false
    }
    
    /// 判断是否为相册
    var isAlbum: Bool {
        if case .album = type {
            return true
        }
        return false
    }
    
    /// 获取相册集合（如果是相册类型）
    var assetCollection: PHAssetCollection? {
        if case .album(let collection) = type {
            return collection
        }
        return nil
    }
    
    /// 获取文件夹集合（如果是文件夹类型）
    var collectionList: PHCollectionList? {
        if case .folder(let list) = type {
            return list
        }
        return nil
    }
}
