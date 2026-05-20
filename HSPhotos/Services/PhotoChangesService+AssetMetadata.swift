//
//  PhotoChangesService+AssetMetadata.swift
//  HSPhotos
//
//  单张照片元数据写操作（日期、位置、从图库删除）。
//

import CoreLocation
import Photos

extension PhotoChangesService {

    // MARK: - 创建日期

    static func updateCreationDate(
        asset: PHAsset,
        date: Date?,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.creationDate = date
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(
                    success,
                    error?.localizedDescription ?? (success ? nil : "调整失败")
                )
            }
        }
    }

    // MARK: - 位置

    static func updateLocation(
        asset: PHAsset,
        location: CLLocation?,
        completion: @escaping SortCompletion
    ) {
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.location = location
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(
                    success,
                    error?.localizedDescription ?? (success ? nil : "操作失败")
                )
            }
        }
    }

    // MARK: - 从图库删除

    static func deleteFromLibrary(
        assets: [PHAsset],
        completion: @escaping SortCompletion
    ) {
        guard !assets.isEmpty else {
            completion(true, nil)
            return
        }
        guard isPhotoLibraryWritable() else {
            completion(false, permissionDeniedMessage)
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(
                    success,
                    error?.localizedDescription ?? (success ? nil : "删除失败")
                )
            }
        }
    }

    // MARK: - 读回

    static func refetchAsset(localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }
}
