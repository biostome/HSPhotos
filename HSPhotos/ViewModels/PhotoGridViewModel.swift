//
//  PhotoGridViewModel.swift
//  HSPhotos
//
//  相簿网格页 MVVM：封装 AlbumSession（Model），统一刷新通知。
//

import Photos

final class PhotoGridViewModel {

    /// 网格绑定与层级 API 仍直接使用 Model（PhotoGridView / ContextMenu）。
    let session: AlbumSession

    /// 成员或筛选变更后通知 Controller 刷新 View（主线程）。
    var onGridNeedsRefresh: (() -> Void)?

    var collection: PHAssetCollection { session.collection }

    var albumOperations: PhotoAlbumOperations { session.albumOperations }

    var sortPreference: PhotoSortPreference {
        get { session.sortPreference }
        set { session.sortPreference = newValue }
    }

    var supportsHierarchyNumbering: Bool {
        get { session.supportsHierarchyNumbering }
        set { session.supportsHierarchyNumbering = newValue }
    }

    var memberAssets: [PHAsset] {
        get { session.memberAssets }
        set {
            session.memberAssets = newValue
            onGridNeedsRefresh?()
        }
    }

    var filterState: TagFilterState {
        get { session.filterState }
        set {
            guard session.filterState != newValue else { return }
            session.filterState = newValue
            onGridNeedsRefresh?()
        }
    }

    init(collection: PHAssetCollection, numbering: PhotoNumberingService = .shared) {
        session = AlbumSession(collection: collection, numbering: numbering)
    }

    func loadNumberingFromStorage() {
        session.loadNumberingFromStorage()
    }

    func saveNumberingToStorage() {
        session.saveNumberingToStorage()
    }

    func cleanupNumbering(validAssetIDs: Set<String>) {
        session.cleanupNumbering(validAssetIDs: validAssetIDs)
    }
}
