//
//  PhotoAlbumOperations.swift
//  HSPhotos
//
//  相簿内写库 Service 门面（Apple MVC：Model 层之上的 Service，非 Web UseCase）。
//  新代码可使用类型别名 PhotoAlbumEditingService。
//

import Foundation
import Photos
import PhotosUI

struct PhotoAlbumOperationOutcome {
    let success: Bool
    let message: String?
    var shouldReloadAssets: Bool = false
    var shouldClearSelection: Bool = false
    var shouldApplyCustomSort: Bool = false
    var undoAction: UndoAction?
}

typealias PhotoAlbumEditingService = PhotoAlbumOperations

final class PhotoAlbumOperations {
    typealias Completion = (PhotoAlbumOperationOutcome) -> Void

    let collection: PHAssetCollection

    init(collection: PHAssetCollection) {
        self.collection = collection
    }

    // MARK: - 自定义顺序写回

    func syncCustomOrder(
        sortedAssets: [PHAsset],
        originalAssets: [PHAsset],
        completion: @escaping Completion
    ) {
        PhotoChangesService.sync(sortedAssets: sortedAssets, for: collection) { success, message in
            var outcome = PhotoAlbumOperationOutcome(success: success, message: message)
            if success {
                outcome.shouldApplyCustomSort = true
                outcome.undoAction = UndoAction.sort(
                    collection: self.collection,
                    originalAssets: originalAssets,
                    sortedAssets: sortedAssets
                )
            }
            completion(outcome)
        }
    }

    // MARK: - 粘贴 / 副本

    /// 按索引插入相簿；撤销由 `PhotoChangesService.paste` 记录。
    func paste(assets: [PHAsset], at insertIndex: Int, completion: @escaping Completion) {
        guard !assets.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: "没有可粘贴的资源"))
            return
        }

        PhotoChangesService.paste(assets: assets, into: collection, at: insertIndex) { success, message in
            completion(
                PhotoAlbumOperationOutcome(
                    success: success,
                    message: message,
                    shouldClearSelection: success,
                    shouldApplyCustomSort: success
                )
            )
        }
    }

    /// 创建副本并加入当前相簿；撤销由 `PhotoChangesService.duplicate` 记录。
    func duplicate(assets: [PHAsset], completion: @escaping Completion) {
        guard !assets.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: "没有可复制的资源"))
            return
        }

        PhotoChangesService.duplicate(assets: assets, to: collection) { success, message in
            completion(
                PhotoAlbumOperationOutcome(
                    success: success,
                    message: message,
                    shouldReloadAssets: success
                )
            )
        }
    }

    // MARK: - 删除 / 移动 / 添加

    func delete(assets: [PHAsset], completion: @escaping Completion) {
        guard !assets.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: "没有可删除的资源"))
            return
        }

        PhotoChangesService.delete(assets: assets, for: collection) { success, message in
            var outcome = PhotoAlbumOperationOutcome(
                success: success,
                message: message,
                shouldReloadAssets: success,
                shouldClearSelection: success
            )
            if success, self.collection.assetCollectionSubtype != .smartAlbumUserLibrary {
                outcome.undoAction = UndoAction.delete(collection: self.collection, assets: assets)
            }
            completion(outcome)
        }
    }

    func move(
        assets: [PHAsset],
        to destination: PHAssetCollection,
        completion: @escaping Completion
    ) {
        guard !assets.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: "没有可移动的资源"))
            return
        }

        PhotoChangesService.move(assets: assets, from: collection, to: destination) { success, message in
            var outcome = PhotoAlbumOperationOutcome(
                success: success,
                message: message,
                shouldReloadAssets: success,
                shouldClearSelection: success
            )
            if success {
                outcome.undoAction = UndoAction.move(
                    sourceCollection: self.collection,
                    destinationCollection: destination,
                    assets: assets
                )
            }
            completion(outcome)
        }
    }

    /// 将资源加入目标相簿（跳过已在其中的成员）。
    func add(assets: [PHAsset], to destination: PHAssetCollection, completion: @escaping Completion) {
        let assetsToAdd = Self.assetsNotInCollection(assets, collection: destination)
        guard !assetsToAdd.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: "所选照片已在目标相簿中"))
            return
        }

        PhotoChangesService.copy(assets: assetsToAdd, to: destination) { success, message in
            let outcome = PhotoAlbumOperationOutcome(
                success: success,
                message: success ? "已添加 \(assetsToAdd.count) 张照片" : message,
                shouldReloadAssets: success && destination.localIdentifier == self.collection.localIdentifier
            )
            completion(outcome)
        }
    }

    /// 从选择器结果加入当前相簿。
    func addPickerResults(_ results: [PHPickerResult], completion: @escaping Completion) {
        let identifiers = results.compactMap(\.assetIdentifier)
        guard !identifiers.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: nil))
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var selected: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            selected.append(asset)
        }
        guard !selected.isEmpty else {
            completion(PhotoAlbumOperationOutcome(success: false, message: nil))
            return
        }

        let assetsToAdd = Self.assetsNotInCollection(selected, collection: collection)
        if assetsToAdd.isEmpty {
            completion(PhotoAlbumOperationOutcome(success: false, message: "所选照片已在该相簿中"))
            return
        }

        Self.ensureReadWritePermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                completion(PhotoAlbumOperationOutcome(success: false, message: "请允许照片读写权限后重试"))
                return
            }

            PhotoChangesService.copy(assets: assetsToAdd, to: self.collection) { success, message in
                let outcome = PhotoAlbumOperationOutcome(
                    success: success,
                    message: success ? "已添加 \(assetsToAdd.count) 张照片" : (message ?? "无法添加照片"),
                    shouldReloadAssets: success
                )
                completion(outcome)
            }
        }
    }

    // MARK: - Helpers

    static func assetsNotInCollection(_ assets: [PHAsset], collection: PHAssetCollection) -> [PHAsset] {
        let existing = PHAsset.fetchAssets(in: collection, options: nil)
        var existingIDs = Set<String>()
        existing.enumerateObjects { asset, _, _ in
            existingIDs.insert(asset.localIdentifier)
        }
        return assets.filter { !existingIDs.contains($0.localIdentifier) }
    }

    static func ensureReadWritePermission(_ completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        default:
            completion(false)
        }
    }
}
