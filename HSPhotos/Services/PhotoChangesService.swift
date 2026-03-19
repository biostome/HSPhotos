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
        let isAllPhotos = collection.assetCollectionSubtype == .smartAlbumUserLibrary
        if isAllPhotos {
            // 「所有照片」：必须用 deleteAssets（智能相册不支持 removeAssets），撤销不可用故不记录
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }, completionHandler: { success, error in
                // 不记录撤销：deleteAssets 后照片移至「最近删除」，无法通过 addAssets 恢复
                DispatchQueue.main.async { completion(success, error?.localizedDescription ?? (success ? nil : "Delete operation failed")) }
            })
        } else {
            // 用户相册：removeAssets 仅从相册移除，照片仍在库中，撤销可 addAssets 恢复
            PHPhotoLibrary.shared().performChanges({
                guard let changeRequest = PHAssetCollectionChangeRequest(for: collection) else { return }
                changeRequest.removeAssets(assets as NSArray)
            }, completionHandler: { success, error in
                // 撤销由 controller 记录
                DispatchQueue.main.async { completion(success, error?.localizedDescription ?? (success ? nil : "Delete operation failed")) }
            })
        }
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
    
    // 创建相片副本的方法
    /// - Parameters:
    ///   - assets: 要创建副本的资源
    ///   - to: 目标相册
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func duplicate(assets: [PHAsset], to destinationCollection: PHAssetCollection, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
        // Check permission
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            completion(false, "No photo library access permission")
            return
        }
        
        guard !assets.isEmpty else {
            completion(false, "No assets to duplicate")
            return
        }
        
        // 使用Photos框架的批量操作来创建副本
        var newAssetIdentifiers: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for asset in assets {
            dispatchGroup.enter()
            
            // 在PHPhotoLibrary的变更块中创建新资产
            PHPhotoLibrary.shared().performChanges({ 
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // 复制元数据
                if let creationDate = asset.creationDate {
                    creationRequest.creationDate = creationDate
                }
                
                if let location = asset.location {
                    creationRequest.location = location
                }
                
                creationRequest.isFavorite = asset.isFavorite
                creationRequest.isHidden = asset.isHidden
                
                // 获取资产资源并添加到创建请求
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources {
                    if resource.type == .adjustmentData || resource.type == .adjustmentBasePhoto {
                        continue
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var accumulatedData = Data()
                    var resourceError: Error?
                    
                    let requestOptions = PHAssetResourceRequestOptions()
                    requestOptions.isNetworkAccessAllowed = true
                    
                    PHAssetResourceManager.default().requestData(for: resource, options: requestOptions, 
                        dataReceivedHandler: { data in
                            accumulatedData.append(data)
                        },
                        completionHandler: { error in
                            if let error = error {
                                resourceError = error
                                semaphore.signal()
                                return
                            }
                            creationRequest.addResource(with: resource.type, data: accumulatedData, options: nil)
                            semaphore.signal()
                        }
                    )
                    
                    semaphore.wait()
                    
                    if let error = resourceError {
                        print("获取资产资源数据失败: \(error.localizedDescription)")
                        continue
                    }
                }
                
                // 保存新资产的占位符
                if let placeholder = creationRequest.placeholderForCreatedAsset {
                    newAssetIdentifiers.append(placeholder.localIdentifier)
                }
            }, completionHandler: { success, error in
                if success {
                    print("资产创建成功")
                } else {
                    print("资产创建失败: \(error?.localizedDescription ?? "未知错误")")
                }
                dispatchGroup.leave()
            })
        }
        
        dispatchGroup.notify(queue: .main) {
            print("所有资产处理完成，新资产标识符数量: \(newAssetIdentifiers.count)")
            if !newAssetIdentifiers.isEmpty {
                // 尝试获取新创建的资产，最多重试3次
                self.fetchNewlyCreatedAssets(identifiers: newAssetIdentifiers, maxRetries: 3, currentRetry: 0) { newAssets in
                    if !newAssets.isEmpty {
                        // 将所有新创建的资产添加到目标相册
                        PHPhotoLibrary.shared().performChanges({ 
                            if let collectionChangeRequest = PHAssetCollectionChangeRequest(for: destinationCollection) {
                                collectionChangeRequest.addAssets(newAssets as NSArray)
                                print("将新资产添加到相册成功")
                            } else {
                                print("无法获取相册变更请求")
                            }
                        }, completionHandler: { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    // 添加撤销操作（仅当不是撤销操作时）
                                    if !isUndoOperation {
                                        let undoAction = UndoAction(
                                            type: .copy(sourceAssets: newAssets, destinationCollection: destinationCollection),
                                            timestamp: Date(),
                                            description: "创建 \(newAssets.count) 张照片的副本"
                                        )
                                        UndoManagerService.shared.addUndoAction(undoAction)
                                    }
                                    completion(true, "已创建 \(newAssets.count) 张照片的副本")
                                } else {
                                    print("将新资产添加到相册失败: \(error?.localizedDescription ?? "未知错误")")
                                    completion(false, error?.localizedDescription ?? "无法将照片添加到相册")
                                }
                            }
                        })
                    } else {
                        completion(false, "无法获取新创建的资产")
                    }
                }
            } else {
                completion(false, "无法创建照片副本")
            }
        }
    }
    
    // 尝试获取新创建的资产，支持重试
    private static func fetchNewlyCreatedAssets(identifiers: [String], maxRetries: Int, currentRetry: Int, completion: @escaping ([PHAsset]) -> Void) {
        // 获取新创建的资产
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var newAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            newAssets.append(asset)
        }
        
        if !newAssets.isEmpty || currentRetry >= maxRetries {
            print("获取新创建的资产完成，重试次数: \(currentRetry)，成功获取: \(newAssets.count) 个")
            completion(newAssets)
        } else {
            print("获取新创建的资产失败，正在重试... (\(currentRetry + 1)/\(maxRetries))")
            // 延迟100毫秒后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.fetchNewlyCreatedAssets(identifiers: identifiers, maxRetries: maxRetries, currentRetry: currentRetry + 1, completion: completion)
            }
        }
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
    
    // 切换照片收藏状态的方法
    /// - Parameters:
    ///   - asset: 要切换收藏状态的资源
    ///   - isUndoOperation: 是否为撤销操作，撤销操作不添加新的撤销记录
    static func toggleFavorite(asset: PHAsset, isUndoOperation: Bool = false, completion: @escaping SortCompletion) {
        // Check permission
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            completion(false, "No photo library access permission")
            return
        }
        
        let newFavoriteStatus = !asset.isFavorite
        
        PHPhotoLibrary.shared().performChanges({ 
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = newFavoriteStatus
        }, completionHandler: { success, error in
            if success && !isUndoOperation {
                // 添加撤销操作（仅当不是撤销操作时）
                let undoAction = UndoAction(
                    type: .favorite(asset: asset, isFavorite: newFavoriteStatus),
                    timestamp: Date(),
                    description: newFavoriteStatus ? "收藏照片" : "取消收藏照片"
                )
                UndoManagerService.shared.addUndoAction(undoAction)
            }
            
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Toggle favorite operation failed"))
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
    
    static func undoFavorite(asset: PHAsset, isFavorite: Bool, completion: @escaping SortCompletion) {
        // 撤销收藏操作，将状态恢复到相反状态
        let newFavoriteStatus = !isFavorite
        PHPhotoLibrary.shared().performChanges({ 
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = newFavoriteStatus
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Undo favorite operation failed"))
            }
        })
    }
    
    static func redoFavorite(asset: PHAsset, isFavorite: Bool, completion: @escaping SortCompletion) {
        // 重做收藏操作，恢复到原来的状态
        PHPhotoLibrary.shared().performChanges({ 
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "Redo favorite operation failed"))
            }
        })
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
        case .favorite(let asset, let isFavorite):
            undoFavorite(asset: asset, isFavorite: isFavorite, completion: completion)
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
        case .favorite(let asset, let isFavorite):
            redoFavorite(asset: asset, isFavorite: isFavorite, completion: completion)
        }
    }
}
