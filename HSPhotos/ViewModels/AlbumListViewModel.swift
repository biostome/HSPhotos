//
//  AlbumListViewModel.swift
//  HSPhotos
//
//  相册列表 MVVM：封装 AlbumListQuery，供 AlbumListViewController 绑定。
//

import Photos

final class AlbumListViewModel {

    /// 数据加载或展开状态变化后回调（主线程）。
    var onDidUpdate: (() -> Void)?

    var sortKind: AlbumListSortKind {
        get { query.sortKind }
        set { query.sortKind = newValue }
    }

    var expandedFolderIDs: Set<String> {
        query.expandedFolderIDs
    }

    var allItems: [AlbumListItem] {
        query.allItems
    }

    private let query: AlbumListQuery

    init(parentList: PHCollectionList? = nil) {
        query = AlbumListQuery(parentList: parentList)
    }

    func reload() {
        query.reload { [weak self] in
            self?.onDidUpdate?()
        }
    }

    func clearAllItems() {
        query.clearAllItems()
    }

    func displayedItems(layoutMode: AlbumListLayoutMode) -> [AlbumListItem] {
        query.displayedItems(for: layoutMode)
    }

    func toggleFolderExpansion(identifier: String) {
        query.toggleFolderExpansion(identifier: identifier)
    }

    @discardableResult
    func toggleExpansion(forSelectedFolderIDs ids: Set<String>) -> Bool {
        query.toggleExpansion(forSelectedFolderIDs: ids)
    }

    func toggleExpandAllFolders() {
        query.toggleExpandAllFolders()
    }

    func allExpandableFolderIDs() -> Set<String> {
        query.allExpandableFolderIDs()
    }

    func selectedExpandableFolderIDs(
        in displayed: [AlbumListItem],
        selectedIdentifiers: Set<String>
    ) -> Set<String> {
        query.selectedExpandableFolderIDs(in: displayed, selectedIdentifiers: selectedIdentifiers)
    }

    func item(withTitle title: String) -> AlbumListItem? {
        query.allItems.first { $0.title == title }
    }
}
