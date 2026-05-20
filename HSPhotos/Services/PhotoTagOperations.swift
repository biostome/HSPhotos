//
//  PhotoTagOperations.swift
//  HSPhotos
//
//  标签 Service 门面（避免与 PhotoTagService 重名，保留 PhotoTagOperations 类名）。
//  类型别名：PhotoTagFacade。
//

import Foundation

typealias PhotoTagFacade = PhotoTagOperations

final class PhotoTagOperations {

    static let shared = PhotoTagOperations()

    private var service: PhotoTagService { .shared }

    private init() {}

    // MARK: - 查询

    func loadTags() -> [PhotoTag] {
        service.loadTags()
    }

    func recentlyUsedTags(limit: Int = 5) -> [PhotoTag] {
        service.recentlyUsedTags(limit: limit)
    }

    func tags(forAsset identifier: String) -> [PhotoTag] {
        service.tags(forAsset: identifier)
    }

    func hasTag(_ tagID: String, forAsset identifier: String) -> Bool {
        service.hasTag(tagID, forAsset: identifier)
    }

    func filteredIdentifiers(by state: TagFilterState) -> Set<String> {
        service.filteredIdentifiers(by: state)
    }

    func previewCount(in candidates: [String], state: TagFilterState) -> Int {
        service.previewCount(in: candidates, state: state)
    }

    /// 按名称模糊匹配，供搜索栏快速过滤。
    func tagIDs(matchingName query: String) -> Set<String> {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let ids = loadTags()
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .map(\.id)
        return Set(ids)
    }

    // MARK: - 变更

    @discardableResult
    func createTag(name: String) -> PhotoTag {
        service.createTag(name: name)
    }

    func deleteTag(id: String) {
        service.deleteTag(id: id)
    }

    func renameTag(id: String, newName: String) {
        service.renameTag(id: id, newName: newName)
    }

    func addAssets(_ identifiers: [String], toTag tagID: String) {
        service.addAssets(identifiers, toTag: tagID)
    }

    func removeAssets(_ identifiers: [String], fromTag tagID: String) {
        service.removeAssets(identifiers, fromTag: tagID)
    }

    func toggleAsset(_ identifier: String, forTag tagID: String) {
        service.toggleAsset(identifier, forTag: tagID)
    }
}
