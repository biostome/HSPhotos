//
//  AlbumCollectionOperations.swift
//  HSPhotos
//
//  相册列表写库 Service 门面。类型别名：AlbumCollectionEditingService。
//

import Photos
import PhotosUI

/// 列表级写操作结果（与相簿内 `PhotoAlbumOperationOutcome` 区分，字段更少）。
struct AlbumCollectionOperationOutcome {
    let success: Bool
    let message: String?

    var isPermissionDenied: Bool {
        message == PhotoChangesService.permissionDeniedMessage
    }
}

typealias AlbumCollectionEditingService = AlbumCollectionOperations

final class AlbumCollectionOperations {

    typealias Completion = (AlbumCollectionOperationOutcome) -> Void

    // MARK: - 相簿 / 文件夹

    func createAlbum(titled title: String, inParent parent: PHCollectionList?, completion: @escaping Completion) {
        requestWriteAccess { granted in
            guard granted else {
                completion(AlbumCollectionOperationOutcome(success: false, message: PhotoChangesService.permissionDeniedMessage))
                return
            }
            PhotoChangesService.createAlbum(titled: title, inParent: parent) { success, message in
                completion(AlbumCollectionOperationOutcome(success: success, message: message))
            }
        }
    }

    func createFolder(titled title: String, inParent parent: PHCollectionList?, completion: @escaping Completion) {
        requestWriteAccess { granted in
            guard granted else {
                completion(AlbumCollectionOperationOutcome(success: false, message: PhotoChangesService.permissionDeniedMessage))
                return
            }
            PhotoChangesService.createFolder(titled: title, inParent: parent) { success, message in
                completion(AlbumCollectionOperationOutcome(success: success, message: message))
            }
        }
    }

    func rename(item: AlbumListItem, to title: String, completion: @escaping Completion) {
        requestWriteAccess { granted in
            guard granted else {
                completion(AlbumCollectionOperationOutcome(success: false, message: PhotoChangesService.permissionDeniedMessage))
                return
            }
            switch item.type {
            case .album(let collection):
                PhotoChangesService.rename(collection: collection, to: title) { success, message in
                    completion(AlbumCollectionOperationOutcome(success: success, message: message))
                }
            case .folder(let list):
                PhotoChangesService.rename(collectionList: list, to: title) { success, message in
                    completion(AlbumCollectionOperationOutcome(success: success, message: message))
                }
            }
        }
    }

    func delete(item: AlbumListItem, completion: @escaping Completion) {
        requestWriteAccess { granted in
            guard granted else {
                completion(AlbumCollectionOperationOutcome(success: false, message: PhotoChangesService.permissionDeniedMessage))
                return
            }
            switch item.type {
            case .album(let collection):
                PhotoChangesService.delete(collection: collection) { success, message in
                    completion(AlbumCollectionOperationOutcome(success: success, message: message))
                }
            case .folder(let list):
                PhotoChangesService.delete(collectionList: list) { success, message in
                    completion(AlbumCollectionOperationOutcome(success: success, message: message))
                }
            }
        }
    }

    // MARK: - 向相簿添加照片（列表页 Picker）

    func addPickerResults(_ results: [PHPickerResult], to album: PHAssetCollection, completion: @escaping (PhotoAlbumOperationOutcome) -> Void) {
        PhotoAlbumOperations(collection: album).addPickerResults(results, completion: completion)
    }

    // MARK: - 权限

    private func requestWriteAccess(_ completion: @escaping (Bool) -> Void) {
        PhotoAlbumOperations.ensureReadWritePermission(completion)
    }
}
