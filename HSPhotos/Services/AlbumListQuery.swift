//
//  AlbumListQuery.swift
//  HSPhotos
//
//  相册列表读模型：从 Photos 加载、排序、列表模式下的展开/可见行计算。
//

import Photos

enum AlbumListSortKind {
    case modificationDate
    case name
    case custom
}

final class AlbumListQuery {

    let parentList: PHCollectionList?

    var sortKind: AlbumListSortKind = .custom

    private(set) var allItems: [AlbumListItem] = []

    private(set) var expandedFolderIDs: Set<String> = []

    init(parentList: PHCollectionList? = nil) {
        self.parentList = parentList
    }

    // MARK: - 加载

    func reload(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let items = self.fetchAllItems()
            DispatchQueue.main.async {
                self.allItems = items
                completion()
            }
        }
    }

    func clearAllItems() {
        allItems.removeAll()
    }

    // MARK: - 展示

    func displayedItems(for layoutMode: AlbumListLayoutMode) -> [AlbumListItem] {
        switch layoutMode {
        case .grid:
            return allItems
        case .list:
            var visitedFolderIDs = Set<String>()
            return buildVisibleItems(from: allItems, level: 0, visitedFolderIDs: &visitedFolderIDs)
        }
    }

    // MARK: - 展开

    func toggleFolderExpansion(identifier: String) {
        if expandedFolderIDs.contains(identifier) {
            expandedFolderIDs.remove(identifier)
        } else {
            expandedFolderIDs.insert(identifier)
        }
    }

    /// 多选模式下：对指定文件夹 ID 做展开/收起（与原先子集逻辑一致）。
    @discardableResult
    func toggleExpansion(forSelectedFolderIDs ids: Set<String>) -> Bool {
        guard !ids.isEmpty else { return false }
        var changed = false
        if ids.isSubset(of: expandedFolderIDs) {
            for id in ids where expandedFolderIDs.contains(id) {
                expandedFolderIDs.remove(id)
                changed = true
            }
        } else {
            for id in ids where !expandedFolderIDs.contains(id) {
                expandedFolderIDs.insert(id)
                changed = true
            }
        }
        return changed
    }

    /// 列表模式「展开全部 / 收起全部」。
    func toggleExpandAllFolders() {
        let expandable = allExpandableFolderIDs()
        guard !expandable.isEmpty else { return }
        if expandable.isSubset(of: expandedFolderIDs) {
            expandedFolderIDs.subtract(expandable)
        } else {
            expandedFolderIDs.formUnion(expandable)
        }
    }

    func allExpandableFolderIDs() -> Set<String> {
        var visited = Set<String>()
        return collectExpandableFolderIDs(from: allItems, visitedFolderIDs: &visited)
    }

    func selectedExpandableFolderIDs(
        in displayed: [AlbumListItem],
        selectedIdentifiers: Set<String>
    ) -> Set<String> {
        var ids = Set<String>()
        for item in displayed {
            guard selectedIdentifiers.contains(item.localIdentifier),
                  item.isFolder,
                  item.canExpand else { continue }
            ids.insert(item.localIdentifier)
        }
        return ids
    }

    // MARK: - Private fetch

    private func fetchAllItems() -> [AlbumListItem] {
        if let parentList {
            return fetchItems(in: parentList)
        }

        var items: [AlbumListItem] = []
        let folderOptions = fetchOptions()
        let allFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: folderOptions)
        let albumOptions = fetchOptions()
        let allAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumOptions)

        var childIDsContainedInSomeFolder = Set<String>()
        allFolders.enumerateObjects { parentFolder, _, _ in
            let subCollections = PHCollection.fetchCollections(in: parentFolder, options: nil)
            subCollections.enumerateObjects { sub, _, _ in
                childIDsContainedInSomeFolder.insert(sub.localIdentifier)
            }
        }

        var topLevelFolders: [PHCollectionList] = []
        allFolders.enumerateObjects { folder, _, _ in
            if !childIDsContainedInSomeFolder.contains(folder.localIdentifier) {
                topLevelFolders.append(folder)
            }
        }

        var topLevelAlbums: [PHAssetCollection] = []
        allAlbums.enumerateObjects { album, _, _ in
            if !childIDsContainedInSomeFolder.contains(album.localIdentifier) {
                topLevelAlbums.append(album)
            }
        }

        for folder in topLevelFolders {
            items.append(AlbumListItem(type: .folder(folder)))
        }
        for album in topLevelAlbums {
            items.append(AlbumListItem(type: .album(album)))
        }
        return items
    }

    private func fetchItems(in collectionList: PHCollectionList) -> [AlbumListItem] {
        var items: [AlbumListItem] = []
        let collections = PHCollection.fetchCollections(in: collectionList, options: fetchOptions())
        collections.enumerateObjects { collection, _, _ in
            if let subFolder = collection as? PHCollectionList {
                items.append(AlbumListItem(type: .folder(subFolder)))
            } else if let subAlbum = collection as? PHAssetCollection {
                items.append(AlbumListItem(type: .album(subAlbum)))
            }
        }
        return items
    }

    private func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        switch sortKind {
        case .modificationDate:
            options.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        case .name:
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        case .custom:
            options.sortDescriptors = nil
        }
        return options
    }

    private func buildVisibleItems(
        from items: [AlbumListItem],
        level: Int,
        visitedFolderIDs: inout Set<String>
    ) -> [AlbumListItem] {
        var visibleItems: [AlbumListItem] = []

        for item in items {
            if item.isFolder, let folder = item.collectionList {
                if visitedFolderIDs.contains(item.localIdentifier) { continue }
                visitedFolderIDs.insert(item.localIdentifier)

                let childItems = fetchItems(in: folder)
                let canExpand = !childItems.isEmpty
                let isExpanded = canExpand && expandedFolderIDs.contains(item.localIdentifier)

                visibleItems.append(makeDisplayItem(from: item, level: level, canExpand: canExpand, isExpanded: isExpanded))

                if isExpanded {
                    visibleItems.append(contentsOf: buildVisibleItems(
                        from: childItems,
                        level: level + 1,
                        visitedFolderIDs: &visitedFolderIDs
                    ))
                }
            } else {
                visibleItems.append(makeDisplayItem(from: item, level: level, canExpand: false, isExpanded: false))
            }
        }
        return visibleItems
    }

    private func makeDisplayItem(
        from item: AlbumListItem,
        level: Int,
        canExpand: Bool,
        isExpanded: Bool
    ) -> AlbumListItem {
        let displayItem = AlbumListItem(type: item.type)
        displayItem.hierarchyLevel = level
        displayItem.canExpand = canExpand
        displayItem.isExpanded = isExpanded
        return displayItem
    }

    private func collectExpandableFolderIDs(
        from items: [AlbumListItem],
        visitedFolderIDs: inout Set<String>
    ) -> Set<String> {
        var folderIDs = Set<String>()

        for item in items {
            guard item.isFolder, let folder = item.collectionList else { continue }
            guard !visitedFolderIDs.contains(item.localIdentifier) else { continue }
            visitedFolderIDs.insert(item.localIdentifier)

            let childItems = fetchItems(in: folder)
            if !childItems.isEmpty {
                folderIDs.insert(item.localIdentifier)
            }
            folderIDs.formUnion(collectExpandableFolderIDs(from: childItems, visitedFolderIDs: &visitedFolderIDs))
        }
        return folderIDs
    }
}
