//
//  UndoManager.swift
//  HSPhotos
//
//  Created by Qwen on 2025/9/11.
//

import Foundation
import Photos

/// 撤销操作类型
enum UndoActionType {
    case sort(collection: PHAssetCollection, originalAssets: [PHAsset], sortedAssets: [PHAsset])
    case delete(collection: PHAssetCollection, assets: [PHAsset])
    case move(sourceCollection: PHAssetCollection, destinationCollection: PHAssetCollection, assets: [PHAsset])
    case copy(sourceAssets: [PHAsset], destinationCollection: PHAssetCollection)
    case paste(assets: [PHAsset], into: PHAssetCollection, at: Int)
}

/// 撤销操作记录
struct UndoAction {
    let type: UndoActionType
    let timestamp: Date
    let description: String
}

class UndoManagerService {
    static let shared = UndoManagerService()
    
    private var undoStack: [UndoAction] = []
    private var redoStack: [UndoAction] = []
    
    private init() {}
    
    /// 添加撤销操作到栈中
    func addUndoAction(_ action: UndoAction) {
        undoStack.append(action)
        // 添加新的撤销操作时，清空重做栈
        redoStack.removeAll()
    }
    
    /// 撤销上一个操作
    func undo() -> UndoAction? {
        guard !undoStack.isEmpty else { return nil }
        
        let action = undoStack.removeLast()
        redoStack.append(action)
        return action
    }
    
    /// 重做上一个撤销的操作
    func redo() -> UndoAction? {
        guard !redoStack.isEmpty else { return nil }
        
        let action = redoStack.removeLast()
        undoStack.append(action)
        return action
    }
    
    /// 检查是否可以撤销
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    /// 检查是否可以重做
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    /// 清空所有撤销和重做操作
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - UndoAction 便捷创建方法
extension UndoAction {
    // 为了方便创建各种类型的 UndoAction，添加这些静态方法
    static func sort(collection: PHAssetCollection, originalAssets: [PHAsset], sortedAssets: [PHAsset]) -> UndoAction {
        return UndoAction(
            type: .sort(collection: collection, originalAssets: originalAssets, sortedAssets: sortedAssets),
            timestamp: Date(),
            description: "排序 \(sortedAssets.count) 张照片"
        )
    }
    
    static func delete(collection: PHAssetCollection, assets: [PHAsset]) -> UndoAction {
        return UndoAction(
            type: .delete(collection: collection, assets: assets),
            timestamp: Date(),
            description: "删除 \(assets.count) 张照片"
        )
    }
    
    static func move(sourceCollection: PHAssetCollection, destinationCollection: PHAssetCollection, assets: [PHAsset]) -> UndoAction {
        return UndoAction(
            type: .move(sourceCollection: sourceCollection, destinationCollection: destinationCollection, assets: assets),
            timestamp: Date(),
            description: "移动 \(assets.count) 张照片"
        )
    }
    
    static func copy(sourceAssets: [PHAsset], destinationCollection: PHAssetCollection) -> UndoAction {
        return UndoAction(
            type: .copy(sourceAssets: sourceAssets, destinationCollection: destinationCollection),
            timestamp: Date(),
            description: "复制 \(sourceAssets.count) 张照片"
        )
    }
    
    static func paste(assets: [PHAsset], into collection: PHAssetCollection, at index: Int) -> UndoAction {
        return UndoAction(
            type: .paste(assets: assets, into: collection, at: index),
            timestamp: Date(),
            description: "粘贴 \(assets.count) 张照片"
        )
    }
}
