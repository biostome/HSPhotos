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
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func sync(sortedAssets: [PHAsset], for collection: PHAssetCollection, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
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
        
        // 保存原始顺序用于撤销
        let originalAssetsCopy = originalAssets
        
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
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .sort(collection: collection, originalAssets: originalAssetsCopy, sortedAssets: sortedAssets),
                    timestamp: Date(),
                    description: "排序照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Sync operation failed"))
            }
        })
    }

    // 删除相片同步方法
    /// - Parameters:
    ///   - assets: 要删除的资源
    ///   - collection: 目标相册
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func delete(assets: [PHAsset], for collection: PHAssetCollection, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
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
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .delete(collection: collection, assets: assets),
                    timestamp: Date(),
                    description: "删除照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Delete operation failed"))
            }
        })
    }
    
    // 移动相片到另一个相册的方法
    /// - Parameters:
    ///   - assets: 要移动的资源
    ///   - from: 源相册
    ///   - to: 目标相册
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func move(assets: [PHAsset], from sourceCollection: PHAssetCollection, to destinationCollection: PHAssetCollection, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
        #if DEBUG
        // 添加日志显示移动的照片顺序（仅 Debug）
        print("✂️ 移动照片顺序:")
        for (index, asset) in assets.enumerated() {
            print("  \(index + 1). \(asset.localIdentifier)")
        }
        #endif
        
        PHPhotoLibrary.shared().performChanges({
            // 1. 从源相册删除照片
            guard let sourceChangeRequest = PHAssetCollectionChangeRequest(for: sourceCollection) else {
                return
            }
            let assetsArray = NSArray(array: assets)
            sourceChangeRequest.removeAssets(assetsArray)
            
            // 2. 将照片添加到目标相册
            guard let destinationChangeRequest = PHAssetCollectionChangeRequest(for: destinationCollection) else {
                return
            }
            destinationChangeRequest.addAssets(assetsArray)
        }, completionHandler: { success, error in
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .move(sourceCollection: sourceCollection, destinationCollection: destinationCollection, assets: assets),
                    timestamp: Date(),
                    description: "移动照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Move operation failed"))
            }
        })
    }
    
    // 复制相片到另一个相册的方法
    /// - Parameters:
    ///   - assets: 要复制的资源
    ///   - to: 目标相册
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func copy(assets: [PHAsset], to destinationCollection: PHAssetCollection, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: destinationCollection) else {
                return
            }
            let assetsArray = NSArray(array: assets)
            changeRequest.addAssets(assetsArray)
        }, completionHandler: { success, error in
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .copy(sourceAssets: assets, destinationCollection: destinationCollection),
                    timestamp: Date(),
                    description: "复制照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Copy operation failed"))
            }
        })
    }
    
    // 粘贴相片到相册的方法
    /// - Parameters:
    ///   - assets: 要粘贴的资源
    ///   - to: 目标相册
    ///   - at: 插入位置
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func paste(assets: [PHAsset], into destinationCollection: PHAssetCollection, at insertIndex: Int, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: destinationCollection) else {
                return
            }
            let assetsArray = NSArray(array: assets)
            changeRequest.insertAssets(assetsArray, at: IndexSet(integer: insertIndex))
        }, completionHandler: { success, error in
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .paste(assets: assets, into: destinationCollection, at: insertIndex),
                    timestamp: Date(),
                    description: "粘贴照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Paste operation failed"))
            }
        })
    }
    
    // MARK: - 撤销操作支持方法
    
    static func undoSort(originalAssets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        sync(sortedAssets: originalAssets, for: collection, isUndoOperation: true, completion: completion)
    }
    
    static func undoDelete(assets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            let assetsArray = NSArray(array: assets)
            changeRequest.addAssets(assetsArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Undo delete operation failed"))
            }
        })
    }
    
    static func undoMove(assets: [PHAsset], from sourceCollection: PHAssetCollection, to destinationCollection: PHAssetCollection, completion: @escaping SortCompletion) {
        move(assets: assets, from: destinationCollection, to: sourceCollection, isUndoOperation: true, completion: completion)
    }
    
    static func undoCopy(assets: [PHAsset], from collection: PHAssetCollection, completion: @escaping SortCompletion) {
        delete(assets: assets, for: collection, isUndoOperation: true, completion: completion)
    }
    
    static func undoPaste(assets: [PHAsset], from collection: PHAssetCollection, completion: @escaping SortCompletion) {
        delete(assets: assets, for: collection, isUndoOperation: true, completion: completion)
    }
    
    // MARK: - 重做操作支持方法
    
    static func redoSort(sortedAssets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        sync(sortedAssets: sortedAssets, for: collection, isUndoOperation: true, completion: completion)
    }
    
    static func redoDelete(assets: [PHAsset], for collection: PHAssetCollection, completion: @escaping SortCompletion) {
        delete(assets: assets, for: collection, isUndoOperation: true, completion: completion)
    }
    
    static func redoMove(assets: [PHAsset], from sourceCollection: PHAssetCollection, to destinationCollection: PHAssetCollection, completion: @escaping SortCompletion) {
        move(assets: assets, from: sourceCollection, to: destinationCollection, isUndoOperation: true, completion: completion)
    }
    
    static func redoCopy(assets: [PHAsset], to destinationCollection: PHAssetCollection, completion: @escaping SortCompletion) {
        copy(assets: assets, to: destinationCollection, isUndoOperation: true, completion: completion)
    }
    
    static func redoPaste(assets: [PHAsset], into destinationCollection: PHAssetCollection, at insertIndex: Int, completion: @escaping SortCompletion) {
        paste(assets: assets, into: destinationCollection, at: insertIndex, isUndoOperation: true, completion: completion)
    }
    
    // MARK: - 统一的撤销和重做方法
    
    // 撤销操作
    static func undo(_ action: UndoAction, completion: @escaping SortCompletion) {
        switch action.type {
        case .sort(let collection, let originalAssets, _):
            undoSort(originalAssets: originalAssets, for: collection, completion: completion)
        case .delete(let collection, let assets):
            undoDelete(assets: assets, for: collection, completion: completion)
        case .move(let sourceCollection, let destinationCollection, let assets):
            undoMove(assets: assets, from: destinationCollection, to: sourceCollection, completion: completion)
        case .copy(let sourceAssets, let destinationCollection):
            undoCopy(assets: sourceAssets, from: destinationCollection, completion: completion)
        case .paste(let assets, let destinationCollection, _):
            undoPaste(assets: assets, from: destinationCollection, completion: completion)
        }
    }
    
    // 重做操作
    static func redo(_ action: UndoAction, completion: @escaping SortCompletion) {
        switch action.type {
        case .sort(let collection, _, let sortedAssets):
            redoSort(sortedAssets: sortedAssets, for: collection, completion: completion)
        case .delete(let collection, let assets):
            redoDelete(assets: assets, for: collection, completion: completion)
        case .move(let sourceCollection, let destinationCollection, let assets):
            redoMove(assets: assets, from: sourceCollection, to: destinationCollection, completion: completion)
        case .copy(let sourceAssets, let destinationCollection):
            redoCopy(assets: sourceAssets, to: destinationCollection, completion: completion)
        case .paste(let assets, let destinationCollection, let insertIndex):
            redoPaste(assets: assets, into: destinationCollection, at: insertIndex, completion: completion)
        }
    }
}
