//
//  PhotoChangesService+Collections.swift
//  HSPhotos
//
//  相簿/文件夹级写操作（唯一 performChanges 入口之一）。
//

import Photos

extension PhotoChangesService {

    // MARK: - 创建

    static func createAlbum(
        titled title: String,
        inParent parent: PHCollectionList?,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            let placeholder = createRequest.placeholderForCreatedAssetCollection
            if let parent,
               let listRequest = PHCollectionListChangeRequest(for: parent) {
                listRequest.addChildCollections([placeholder as Any] as NSArray)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "创建相册失败"))
            }
        }
    }

    static func createFolder(
        titled title: String,
        inParent parent: PHCollectionList?,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let createRequest = PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: title)
            let placeholder = createRequest.placeholderForCreatedCollectionList
            if let parent,
               let listRequest = PHCollectionListChangeRequest(for: parent) {
                listRequest.addChildCollections([placeholder as Any] as NSArray)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "创建文件夹失败"))
            }
        }
    }

    // MARK: - 重命名

    static func rename(
        collection: PHAssetCollection,
        to title: String,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.title = title
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "更新标题失败"))
            }
        }
    }

    static func rename(
        collectionList: PHCollectionList,
        to title: String,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let request = PHCollectionListChangeRequest(for: collectionList)
            request?.title = title
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "更新标题失败"))
            }
        }
    }

    // MARK: - 删除

    static func delete(
        collection: PHAssetCollection,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "删除相册失败"))
            }
        }
    }

    static func delete(
        collectionList: PHCollectionList,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHCollectionListChangeRequest.deleteCollectionLists([collectionList] as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription ?? (success ? nil : "删除文件夹失败"))
            }
        }
    }

    // MARK: - 权限

    static let permissionDeniedMessage = "请允许照片读写权限后重试"

    static func isPhotoLibraryWritable() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
}
