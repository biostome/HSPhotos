//
//  PhotoSortor.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/29.
//

import Foundation
import Photos

class PhotoChangesService {
    
    typealias SortCompletion = (Bool, String?) -> Void
    
    /// 将修改的顺序同步到系统相册
    /// - Parameters:
    ///   - sortedAssets: 已经改变顺序的数据
    ///   - collection: 目标相册
    static func sync(sortedAssets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        // Check permission
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            completion(false, "No photo library access permission")
            return
        }
        
        // Fetch original assets efficiently
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        let count = fetchResult.count
        guard count > 0 else {
            completion(false, "No assets in collection")
            return
        }
        
        var originalAssets = [PHAsset]()
        originalAssets.reserveCapacity(count)
        for i in 0..<count {
            originalAssets.append(fetchResult.object(at: i))
        }
        
        // Validate sortedAssets
        guard sortedAssets.count == count else {
            completion(false, "Sorted assets count must match collection assets count")
            return
        }
        
        // Validate that sortedAssets contains exactly the same assets as originalAssets
        let originalSet = Set(originalAssets.map { $0.localIdentifier })
        let sortedSet = Set(sortedAssets.map { $0.localIdentifier })
        guard originalSet == sortedSet else {
            completion(false, "Sorted assets must exactly match the original assets")
            return
        }
        
        // Convert sortedAssets to NSArray for replaceAssets
        let sortedAssetsNSArray = sortedAssets as NSArray
        
        // Execute reorder using replaceAssets
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            
            let indices = IndexSet(0..<count)
            changeRequest.replaceAssets(at: indices, withAssets: sortedAssetsNSArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Sync operation failed"))
            }
        })
    }

    // 删除相片同步方法
    static func delete(assets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        PHPhotoLibrary.shared().performChanges({
            // Remove assets from the collection
            guard let changeRequest = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            // Convert to NSArray for the method call
            let assetsArray = NSArray(array: assets)
            
            // Remove assets from the collection
            changeRequest.removeAssets(assetsArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Delete operation failed"))
            }
        })
    }
}
