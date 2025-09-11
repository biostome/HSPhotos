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