//
//  AlbumGridMenuBuilder.swift
//  HSPhotos
//
//  相簿网格页工具栏/操作菜单纯构建（无业务副作用）。
//

import UIKit

struct AlbumGridHierarchyMenuContext {
    let prevLevel: Int
    let firstLevel: Int
    let anyInHierarchy: Bool
    let anyCanPromote: Bool
    let canDemote: Bool
}

struct AlbumGridMenuState {
    var sortPreference: PhotoSortPreference
    var hasSelection: Bool
    var canUndo: Bool
    var canRedo: Bool
    var supportsHierarchyNumbering: Bool
    var hierarchy: AlbumGridHierarchyMenuContext?
}

struct AlbumGridMenuActions {
    var onSort: (PhotoSortPreference) -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onAddToAlbum: () -> Void
    var onTag: () -> Void
    var onDelete: () -> Void
    var onMove: () -> Void
    var onPaste: () -> Void
    var onCopy: () -> Void
    var onDuplicate: () -> Void
    var onReorder: () -> Void
    var onBatchSetMainLevel: () -> Void
    var onBatchPromote: () -> Void
    var onBatchDemote: () -> Void
    var onBatchSetSameLevel: () -> Void
    var onBatchSetSubLevel: () -> Void
    var onBatchClearLevel: () -> Void
}

enum AlbumGridMenuBuilder {

    static func makeSortMenu(state: AlbumGridMenuState, actions: AlbumGridMenuActions) -> UIMenu {
        let creationDateAction = UIAction(
            title: "按最旧的排最前排序",
            image: UIImage(systemName: "camera"),
            state: state.sortPreference == .creationDate ? .on : .off
        ) { _ in actions.onSort(.creationDate) }

        let newestSortAction = UIAction(
            title: "按最新的排最前排序",
            image: UIImage(systemName: "clock"),
            state: state.sortPreference == .newest ? .on : .off
        ) { _ in actions.onSort(.newest) }

        let customAction = UIAction(
            title: "按自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: state.sortPreference == .custom ? .on : .off
        ) { _ in actions.onSort(.custom) }

        return UIMenu(title: "排序方式", children: [customAction, newestSortAction, creationDateAction])
    }

    static func makeOperationMenu(state: AlbumGridMenuState, actions: AlbumGridMenuActions) -> UIMenu {
        let attributes: UIMenuElement.Attributes = state.hasSelection ? [] : .disabled

        let undoAction = UIAction(
            title: "撤销",
            image: UIImage(systemName: "arrow.uturn.left"),
            attributes: state.canUndo ? [] : .disabled
        ) { _ in actions.onUndo() }

        let redoAction = UIAction(
            title: "重做",
            image: UIImage(systemName: "arrow.uturn.right"),
            attributes: state.canRedo ? [] : .disabled
        ) { _ in actions.onRedo() }

        let addToAlbum = UIAction(
            title: "添加到相簿",
            image: UIImage(systemName: "plus.rectangle.on.folder"),
            attributes: attributes
        ) { _ in actions.onAddToAlbum() }

        let copy = UIAction(
            title: "拷贝",
            image: UIImage(systemName: "doc.on.doc"),
            attributes: attributes
        ) { _ in actions.onCopy() }

        let duplicate = UIAction(
            title: "复制",
            image: UIImage(systemName: "doc.on.doc.fill"),
            attributes: attributes
        ) { _ in actions.onDuplicate() }

        let paste = UIAction(
            title: "粘贴",
            image: UIImage(systemName: "doc.on.clipboard")
        ) { _ in actions.onPaste() }

        let sort = UIAction(
            title: "排序",
            image: UIImage(systemName: "arrow.up.arrow.down"),
            attributes: attributes
        ) { _ in actions.onReorder() }

        let delete = UIAction(
            title: "删除",
            image: UIImage(systemName: "trash"),
            attributes: [attributes, .destructive]
        ) { _ in actions.onDelete() }

        let move = UIAction(
            title: "剪切",
            image: UIImage(systemName: "scissors"),
            attributes: attributes
        ) { _ in actions.onMove() }

        let tagAction = UIAction(
            title: "添加标签",
            image: UIImage(systemName: "tag"),
            attributes: attributes
        ) { _ in actions.onTag() }

        var menuChildren: [UIMenuElement] = [undoAction, redoAction, addToAlbum, tagAction]

        if state.sortPreference == .custom,
           state.supportsHierarchyNumbering,
           let hierarchy = state.hierarchy {
            menuChildren.append(makeHierarchyMenu(context: hierarchy, attributes: attributes, actions: actions))
        }

        menuChildren += [delete, move, paste, copy, duplicate, sort]
        return UIMenu(title: "操作选项", children: menuChildren)
    }

    private static func makeHierarchyMenu(
        context: AlbumGridHierarchyMenuContext,
        attributes: UIMenuElement.Attributes,
        actions: AlbumGridMenuActions
    ) -> UIMenu {
        var children: [UIMenuElement] = []

        children.append(UIAction(
            title: "批量设为主级",
            image: UIImage(systemName: "list.number"),
            attributes: attributes
        ) { _ in actions.onBatchSetMainLevel() })

        if context.anyCanPromote {
            children.append(UIAction(
                title: "批量提升层级",
                image: UIImage(systemName: "arrow.left"),
                attributes: attributes
            ) { _ in actions.onBatchPromote() })
        }

        if context.canDemote {
            children.append(UIAction(
                title: "批量下降层级",
                image: UIImage(systemName: "arrow.right"),
                attributes: attributes
            ) { _ in actions.onBatchDemote() })
        }

        if context.prevLevel > 0 {
            children.append(UIAction(
                title: "批量设为同级",
                image: UIImage(systemName: "arrow.right.to.line"),
                attributes: attributes
            ) { _ in actions.onBatchSetSameLevel() })

            children.append(UIAction(
                title: "批量设为子级",
                image: UIImage(systemName: "list.bullet.indent"),
                attributes: attributes
            ) { _ in actions.onBatchSetSubLevel() })
        }

        if context.anyInHierarchy {
            children.append(UIAction(
                title: "批量取消编号",
                image: UIImage(systemName: "xmark.circle"),
                attributes: attributes.union(.destructive)
            ) { _ in actions.onBatchClearLevel() })
        }

        return UIMenu(title: "层级操作", children: children)
    }
}
