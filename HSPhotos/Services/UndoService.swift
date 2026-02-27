import Foundation

class UndoService {
    private var undoStack: [UndoAction] = []
    private var redoStack: [UndoAction] = []
    
    /// 添加撤销操作
    /// - Parameter action: 撤销操作
    func addAction(_ action: UndoAction) {
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    /// 执行撤销
    /// - Returns: 是否执行成功
    func undoAction() -> Bool {
        guard !undoStack.isEmpty else {
            return false
        }
        
        let action = undoStack.removeLast()
        action.undo()
        redoStack.append(action)
        return true
    }
    
    /// 执行重做
    /// - Returns: 是否执行成功
    func redoAction() -> Bool {
        guard !redoStack.isEmpty else {
            return false
        }
        
        let action = redoStack.removeLast()
        action.redo()
        undoStack.append(action)
        return true
    }
    
    /// 检查是否可以撤销
    /// - Returns: 是否可以撤销
    func canUndo() -> Bool {
        return !undoStack.isEmpty
    }
    
    /// 检查是否可以重做
    /// - Returns: 是否可以重做
    func canRedo() -> Bool {
        return !redoStack.isEmpty
    }
    
    /// 清空撤销重做栈
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}