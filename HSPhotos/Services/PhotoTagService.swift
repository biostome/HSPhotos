//
//  PhotoTagService.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//
//  运行时仅使用内存缓存，UserDefaults 仅在首次加载及变更时读写
//

import Foundation

class PhotoTagService {

    static let shared = PhotoTagService()
    private init() {}

    private let tagsKey = "custom_photo_tags"
    private var tagsCache: [PhotoTag]?

    // MARK: - Load / Save

    /// 首次调用时从 UserDefaults 加载到内存，后续从内存读取
    func loadTags() -> [PhotoTag] {
        if let cached = tagsCache { return cached }
        let tags: [PhotoTag]
        if let data = UserDefaults.standard.data(forKey: tagsKey) {
            tags = (try? JSONDecoder().decode([PhotoTag].self, from: data)) ?? []
        } else {
            tags = []
        }
        tagsCache = tags
        return tags
    }

    /// 仅变更时写入 UserDefaults
    private func saveTags(_ tags: [PhotoTag]) {
        tagsCache = tags
        guard let data = try? JSONEncoder().encode(tags) else { return }
        UserDefaults.standard.set(data, forKey: tagsKey)
    }

    // MARK: - CRUD

    @discardableResult
    func createTag(name: String) -> PhotoTag {
        var tags = loadTags()
        let tag = PhotoTag(name: name)
        tags.append(tag)
        saveTags(tags)
        return tag
    }

    func deleteTag(id: String) {
        var tags = loadTags()
        tags.removeAll { $0.id == id }
        saveTags(tags)
    }

    func renameTag(id: String, newName: String) {
        var tags = loadTags()
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].name = newName
        saveTags(tags)
    }

    // MARK: - 为照片关联标签

    func addAssets(_ identifiers: [String], toTag tagID: String) {
        var tags = loadTags()
        guard let index = tags.firstIndex(where: { $0.id == tagID }) else { return }
        let existing = Set(tags[index].assetIdentifiers)
        let newIDs = identifiers.filter { !existing.contains($0) }
        tags[index].assetIdentifiers.append(contentsOf: newIDs)
        tags[index].lastUsedAt = Date()
        saveTags(tags)
    }

    func removeAssets(_ identifiers: [String], fromTag tagID: String) {
        var tags = loadTags()
        guard let index = tags.firstIndex(where: { $0.id == tagID }) else { return }
        let removeSet = Set(identifiers)
        tags[index].assetIdentifiers.removeAll { removeSet.contains($0) }
        saveTags(tags)
    }

    func toggleAsset(_ identifier: String, forTag tagID: String) {
        var tags = loadTags()
        guard let index = tags.firstIndex(where: { $0.id == tagID }) else { return }
        if tags[index].assetIdentifiers.contains(identifier) {
            tags[index].assetIdentifiers.removeAll { $0 == identifier }
        } else {
            tags[index].assetIdentifiers.append(identifier)
        }
        tags[index].lastUsedAt = Date()
        saveTags(tags)
    }

    // MARK: - 查询

    func tags(forAsset identifier: String) -> [PhotoTag] {
        loadTags().filter { $0.assetIdentifiers.contains(identifier) }
    }

    func hasTag(_ tagID: String, forAsset identifier: String) -> Bool {
        loadTags().first(where: { $0.id == tagID })?.assetIdentifiers.contains(identifier) ?? false
    }

    // MARK: - 过滤核心方法

    func filteredIdentifiers(by state: TagFilterState) -> Set<String> {
        guard state.isActive else { return [] }
        let tags = loadTags()
        let selectedTags = tags.filter { state.selectedTagIDs.contains($0.id) }
        switch state.matchRule {
        case .any:
            return selectedTags.reduce(into: Set<String>()) { result, tag in
                result.formUnion(tag.assetIdentifiers)
            }
        case .all:
            guard let first = selectedTags.first else { return [] }
            var result = Set(first.assetIdentifiers)
            for tag in selectedTags.dropFirst() {
                result.formIntersection(tag.assetIdentifiers)
            }
            return result
        }
    }

    func previewCount(in candidates: [String], state: TagFilterState) -> Int {
        guard state.isActive else { return candidates.count }
        let matched = filteredIdentifiers(by: state)
        return candidates.filter { matched.contains($0) }.count
    }

    // MARK: - 最近使用

    func recentlyUsedTags(limit: Int = 5) -> [PhotoTag] {
        loadTags()
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
}
