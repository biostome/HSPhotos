//
//  AlbumSession.swift
//  HSPhotos
//
//  相簿网格页的 Model 状态（Apple MVC 中的 Model，非 Web 的 Domain 层）。
//  - memberAssets：系统相簿成员在当前排序下的全量顺序
//  - tagFilteredMembers / visibleRowsForGrid：网格展示序列的唯一计算入口
//
//  Controller（BasePhotoViewController）协调本类型与 PhotoGridView；View 不直接改 memberAssets。
//

import Foundation
import Photos

final class AlbumSession {

    let collection: PHAssetCollection

    /// 相簿成员全量顺序（与系统相簿一致，经 fetch / 写回后更新）。
    var memberAssets: [PHAsset] = []

    var sortPreference: PhotoSortPreference = .custom

    var filterState = TagFilterState()

    /// 图库为 false；用户相簿内网格为 true。
    var supportsHierarchyNumbering: Bool = true

    let albumOperations: PhotoAlbumOperations
    let numbering: PhotoNumberingService

    init(
        collection: PHAssetCollection,
        numbering: PhotoNumberingService = .shared
    ) {
        self.collection = collection
        self.numbering = numbering
        self.albumOperations = PhotoAlbumOperations(collection: collection)
    }

    // MARK: - 编号持久化

    func loadNumberingFromStorage() {
        numbering.loadForCollection(collection)
    }

    func saveNumberingToStorage() {
        numbering.saveForCollection(collection)
    }

    func cleanupNumbering(validAssetIDs: Set<String>) {
        numbering.cleanupInvalidNodes(
            validAssetIDs: validAssetIDs,
            orderedAssets: memberAssets,
            for: collection
        )
    }

    // MARK: - 展示用序列

    /// 标签筛选后的成员（仍保持 member 顺序）。
    func tagFilteredMembers() -> [PHAsset] {
        guard filterState.isActive else { return memberAssets }
        let matched = PhotoTagOperations.shared.filteredIdentifiers(by: filterState)
        return memberAssets.filter { matched.contains($0.localIdentifier) }
    }

    /// 网格 cell 对应可见行（自定义排序且支持层级时含折叠过滤）。
    func visibleRowsForGrid() -> [PHAsset] {
        let input = tagFilteredMembers()
        guard sortPreference == .custom, supportsHierarchyNumbering else {
            return input
        }
        return numbering.visibleAssets(from: input, in: collection)
    }
}
